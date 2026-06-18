import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/models/order_item.dart';
import '../new_order/new_order_controller.dart';
import 'ai_order_summary_sheet.dart';

class VoiceAssistantFab extends ConsumerStatefulWidget {
  const VoiceAssistantFab({super.key});

  @override
  ConsumerState<VoiceAssistantFab> createState() => _VoiceAssistantFabState();
}

class _VoiceAssistantFabState extends ConsumerState<VoiceAssistantFab> with SingleTickerProviderStateMixin {
  late final AudioRecorder _audioRecorder;
  bool _isRecording = false;
  bool _isProcessing = false;
  String? _tempPath;
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _pulseController.reverse();
        } else if (status == AnimationStatus.dismissed && _isRecording) {
          _pulseController.forward();
        }
      });
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        HapticFeedback.lightImpact();
        
        final tempDir = await getTemporaryDirectory();
        _tempPath = '${tempDir.path}/voice_memo_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc), 
          path: _tempPath!
        );
        
        setState(() {
          _isRecording = true;
        });
        _pulseController.forward();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Permiso de micrófono denegado. Habilítalo en los ajustes.'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al acceder al micrófono')),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    HapticFeedback.mediumImpact();
    
    setState(() {
      _isRecording = false;
      _isProcessing = true;
    });
    
    _pulseController.stop();
    _pulseController.value = 1.0; // Reset animation
    
    try {
      final path = await _audioRecorder.stop();
      if (path != null) {
        await _processAudio(path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al procesar el audio')),
        );
      }
    } finally {
      setState(() {
        _isProcessing = false;
      });
      
      // Limpieza Extrema de Caché (Crítico)
      if (_tempPath != null) {
        try {
          final file = File(_tempPath!);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {}
      }
    }
  }

  Future<void> _processAudio(String path) async {
    try {
      final formData = FormData.fromMap({
        'audio': await MultipartFile.fromFile(path),
      });

      final dio = DioClient().dio;
      final response = await dio.post('/ai/process-voice', data: formData);

      final data = response.data['data'];
      if (data == null || data['intent'] == 'unknown') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No pude entender el pedido.')),
          );
        }
        return;
      }

      if (data['intent'] == 'create_order') {
        if (mounted) {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (ctx) => AiOrderSummarySheet(
              aiData: response.data,
              onCancel: () {
                Navigator.of(ctx).pop();
              },
              onConfirm: () async {
                Navigator.of(ctx).pop();

                final clientName = data['client_name'] as String?;
                final isNewClient = data['is_new_client'] as bool? ?? false;
                final suggestedClientsRaw = data['suggested_clients'] as List<dynamic>? ?? [];
                final suggestedClients = suggestedClientsRaw.map((e) => Map<String, dynamic>.from(e)).toList();

                final rawItems = data['items'] as List<dynamic>? ?? [];
                final eventDateStr = data['event_date'] as String?;

                DateTime? eventDate;
                if (eventDateStr != null) {
                  eventDate = DateTime.tryParse(eventDateStr);
                }

                // BUG-V02: Leer y parsear el horario que ahora llega del backend
                TimeOfDay? startTime;
                final startTimeStr = data['start_time'] as String?;
                if (startTimeStr != null && startTimeStr.isNotEmpty) {
                  final parts = startTimeStr.split(':');
                  if (parts.length >= 2) {
                    final hour = int.tryParse(parts[0]);
                    final minute = int.tryParse(parts[1]);
                    if (hour != null && minute != null) {
                      startTime = TimeOfDay(hour: hour, minute: minute);
                    }
                  }
                }

                // Los items ya vienen con campos planos (fillings, extras, quantity, weight_kg)
                // gracias al fix en AiBrainService::parseOrderArguments
                final items = rawItems.map((item) {
                  final productName = item['matched_name'] as String?
                      ?? item['name'] as String?
                      ?? item['original_name'] as String?
                      ?? 'Desconocido';
                  final fillings = (item['fillings'] as List<dynamic>?)?.cast<String>() ?? [];
                  final extras   = (item['extras']   as List<dynamic>?)?.cast<String>() ?? [];
                  final weight   = (item['weight_kg'] as num?)?.toDouble();
                  final isUnit   = item['is_unit_sale'] == true;

                  return OrderItem(
                    name: productName,
                    qty: (item['quantity'] as num?)?.toDouble() ?? 1.0,
                    basePrice: (item['base_price'] as num?)?.toDouble() ?? 0.0,
                    customizationNotes: item['customization_notes'] as String?,
                    customizationJson: {
                      ...(item['customization_json'] as Map<String, dynamic>? ?? {}),
                      if (weight != null)        'weight_kg': weight,
                      if (isUnit)                'is_unit_sale': true,
                      if (fillings.isNotEmpty)   'selected_fillings': fillings,
                      if (extras.isNotEmpty)     'selected_extras_kg':
                          extras.map((e) => {'name': e, 'price': 0.0}).toList(),
                    },
                  );
                }).toList();

                // Mantener provider vivo (NewOrderController está AutoDispose)
                final sub = ref.listenManual(newOrderControllerProvider, (_, __) {});

                if (clientName != null) {
                  await ref.read(newOrderControllerProvider.notifier).prefillFromVoiceAssistant(
                    clientName: clientName,
                    isNewClient: isNewClient,
                    eventDate: eventDate,
                    startTime: startTime,       // BUG-V02: pasar horario al controller
                    items: items,
                    suggestedClients: suggestedClients,
                  );
                }

                if (mounted) {
                  await context.push('/new_order');
                }

                sub.close();
              },
            ),
          );
        }
      }

    } on DioException catch (e) {
      if (mounted) {
        String errMsg = 'Error de conexión: ${e.message}';
        if (e.response?.data != null && e.response!.data is Map && e.response!.data['error'] != null) {
          errMsg = e.response!.data['error'].toString();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errMsg),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ocurrió un error inesperado.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isProcessing) {
      return FloatingActionButton(
        onPressed: null,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: FloatingActionButton(
            onPressed: () {
              if (_isRecording) {
                _stopRecording();
              } else {
                _startRecording();
              }
            },
            backgroundColor: _isRecording ? Colors.red : Theme.of(context).colorScheme.primary,
            child: Icon(
              _isRecording ? Icons.mic : Icons.mic_none,
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }
}
