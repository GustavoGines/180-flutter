import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../settings_repository.dart';

class AdminSettingsPage extends ConsumerStatefulWidget {
  const AdminSettingsPage({super.key});

  @override
  ConsumerState<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends ConsumerState<AdminSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _shippingController = TextEditingController();
  final _hoursController = TextEditingController();
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await ref.read(settingsRepoProvider).getAllSettings();
    setState(() {
      _shippingController.text = settings['shipping_cost']?.toString() ?? '0';
      _hoursController.text = settings['business_hours']?.toString() ?? 'Lunes a Sábados de 9 a 18hs';
    });
  }

  @override
  void dispose() {
    _shippingController.dispose();
    _hoursController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    try {
      await ref.read(settingsRepoProvider).updateSettings([
        {
          'key': 'shipping_cost',
          'value': double.tryParse(_shippingController.text) ?? 0,
          'type': 'decimal'
        },
        {
          'key': 'business_hours',
          'value': _hoursController.text,
          'type': 'string'
        }
      ]);
      
      ref.invalidate(remoteSettingsProvider); // Refresh global state
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [Icon(Icons.check_circle, color: Colors.white), SizedBox(width: 8), Text('Ajustes guardados correctamente')]),
          backgroundColor: Colors.green.shade600,
        ),
      );
      Navigator.pop(context);
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data['message'] ?? 'Error al guardar los ajustes';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Theme.of(context).colorScheme.error));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error inesperado: $e'), backgroundColor: Theme.of(context).colorScheme.error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(title: const Text('Administración del Negocio')),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Costos y Logística', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: cs.primary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _shippingController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Costo de Envío Base (\$)', 
                      border: OutlineInputBorder(), 
                      prefixIcon: Icon(Icons.local_shipping_outlined)
                    ),
                    validator: (v) => v!.trim().isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 32),
                  
                  Text('Atención al Cliente', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: cs.primary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _hoursController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Horarios de Atención', 
                      border: OutlineInputBorder(), 
                      prefixIcon: Icon(Icons.schedule_outlined)
                    ),
                    validator: (v) => v!.trim().isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 32),
                  
                  FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.save),
                    label: const Text('Guardar Cambios', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}
