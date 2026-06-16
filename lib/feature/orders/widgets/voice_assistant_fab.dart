import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/dio_client.dart';
import '../new_order/new_order_controller.dart';
import '../../../../core/models/order_item.dart';

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
        final clientName = data['client_name'] as String?;
        final isNewClient = data['is_new_client'] as bool? ?? false;
        final rawItems = data['items'] as List<dynamic>? ?? [];
        final eventDateStr = data['event_date'] as String?;
        
        DateTime? eventDate;
        if (eventDateStr != null) {
          eventDate = DateTime.tryParse(eventDateStr);
        }

        final items = rawItems.map((item) {
          final productName = item['matched_name'] as String? ?? item['original_name'] as String? ?? 'Desconocido';
          return OrderItem(
            name: productName,
            qty: (item['quantity'] as num?)?.toDouble() ?? 1.0,
            basePrice: 0.0, // Necesitaríamos el precio real del producto
            customizationNotes: item['notes'] as String?,
          );
        }).toList();

        // Si tenemos datos suficientes, saltamos a la página de nuevo pedido
        if (mounted) {
          context.push('/orders/new');
          
          if (clientName != null) {
            // Llenar datos pre-procesados
            ref.read(newOrderControllerProvider.notifier).prefillFromVoiceAssistant(
              clientName: clientName,
              isNewClient: isNewClient,
              eventDate: eventDate,
              items: items,
            );
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Pedido iniciado para $clientName')),
            );
          }
        }
      }

    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error de conexión: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ocurrió un error inesperado.')),
        );
      }
    } finally {
      // Limpieza de Caché (Crítico)
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        // Ignorar error al borrar temporal
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

    return GestureDetector(
      onLongPress: _startRecording,
      onLongPressEnd: (_) => _stopRecording(),
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: FloatingActionButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Mantén presionado para hablar')),
                );
              },
              backgroundColor: _isRecording ? Colors.red : Theme.of(context).colorScheme.primary,
              child: Icon(
                _isRecording ? Icons.mic : Icons.mic_none,
                color: Colors.white,
              ),
            ),
          );
        },
      ),
    );
  }
}
