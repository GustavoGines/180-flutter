// address_form_dialog.dart (CON CAMBIOS)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasteleria_180_flutter/core/models/client_address.dart';
// Asegúrate de que esta ruta sea correcta según tu estructura
import 'package:pasteleria_180_flutter/feature/clients/clients_repository.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

// --- NUEVO IMPORT ---
import 'package:google_maps_flutter/google_maps_flutter.dart'; // Para LatLng
import 'map_picker_page.dart'; // La nueva pantalla
// --------------------

class AddressFormDialog extends ConsumerStatefulWidget {
  final int clientId;
  final ClientAddress? addressToEdit;

  const AddressFormDialog({
    super.key,
    required this.clientId,
    this.addressToEdit,
  });

  @override
  ConsumerState<AddressFormDialog> createState() => _AddressFormDialogState();
}

class _AddressFormDialogState extends ConsumerState<AddressFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _labelController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _gmapsController = TextEditingController();

  bool _isLoading = false;
  bool _isGettingLocation = false;

  bool get isEditMode => widget.addressToEdit != null;

  @override
  void initState() {
    super.initState();
    if (isEditMode) {
      _labelController.text = widget.addressToEdit!.label ?? '';
      _addressController.text = widget.addressToEdit!.addressLine1 ?? '';
      _notesController.text = widget.addressToEdit!.notes ?? '';
      _latController.text = widget.addressToEdit!.latitude?.toString() ?? '';
      _lngController.text = widget.addressToEdit!.longitude?.toString() ?? '';
      _gmapsController.text = widget.addressToEdit!.googleMapsUrl ?? '';
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _gmapsController.dispose();
    super.dispose();
  }

  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    final cs = Theme.of(context).colorScheme;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: isError ? TextStyle(color: cs.onError) : null,
        ),
        backgroundColor: isError ? cs.error : null,
      ),
    );
  }

  Future<void> _getUserLocation() async {
    setState(() => _isGettingLocation = true);
    try {
      var status = await Permission.locationWhenInUse.request();
      if (status.isGranted) {
        bool isLocationServiceEnabled =
            await Geolocator.isLocationServiceEnabled();
        if (!isLocationServiceEnabled) {
          _showSnackbar(
            'Por favor, activa el GPS de tu dispositivo.',
            isError: true,
          );
          setState(() => _isGettingLocation = false);
          return;
        }
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        _latController.text = position.latitude.toStringAsFixed(7);
        _lngController.text = position.longitude.toStringAsFixed(7);
        _showSnackbar('Ubicación obtenida con éxito.');
      } else if (status.isDenied || status.isPermanentlyDenied) {
        _showSnackbar('Permiso de ubicación denegado.', isError: true);
        if (status.isPermanentlyDenied) {
          await openAppSettings();
        }
      }
    } catch (e) {
      _showSnackbar('Error al obtener la ubicación: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isGettingLocation = false);
      }
    }
  }

  Future<void> _openMapPicker() async {
    final double? currentLat = double.tryParse(_latController.text);
    final double? currentLng = double.tryParse(_lngController.text);
    LatLng? initialCoords;

    if (currentLat != null && currentLng != null) {
      initialCoords = LatLng(currentLat, currentLng);
    }

    final LatLng? selectedLocation = await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => MapPickerPage(initialCoordinates: initialCoords),
      ),
    );

    if (selectedLocation != null && mounted) {
      _latController.text = selectedLocation.latitude.toStringAsFixed(7);
      _lngController.text = selectedLocation.longitude.toStringAsFixed(7);
      _showSnackbar('Ubicación seleccionada desde el mapa.');
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    final double? latitude = double.tryParse(_latController.text.trim());
    final double? longitude = double.tryParse(_lngController.text.trim());

    final payload = {
      'label': _labelController.text.trim(),
      'address_line_1': _addressController.text.trim(),
      'notes': _notesController.text.trim(),
      'latitude': latitude,
      'longitude': longitude,
      'google_maps_url': _gmapsController.text.trim(),
    };

    try {
      final repo = ref.read(clientsRepoProvider);
      if (isEditMode) {
        await repo.updateAddress(
          widget.clientId,
          widget.addressToEdit!.id,
          payload,
        );
      } else {
        await repo.createAddress(widget.clientId, payload);
      }

      ref.invalidate(clientDetailsProvider(widget.clientId));

      if (mounted) {
        _showSnackbar(
          isEditMode ? 'Dirección actualizada' : 'Dirección añadida con éxito',
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      _showSnackbar('Error al guardar: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isButtonDisabled = _isLoading || _isGettingLocation;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // --- ❗️ CAMBIO AQUÍ: Se eliminó el Container con padding de viewInsets ---
    // El padding para el teclado se maneja en 'client_detail_page.dart'
    // al llamar a este modal.
    return Form(
      key: _formKey,
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            isEditMode ? 'Editar Dirección' : 'Nueva Dirección',
            style: textTheme.headlineSmall?.copyWith(
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _labelController,
            decoration: const InputDecoration(
              labelText: 'Etiqueta * (Ej: Casa, Oficina)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.label_outline),
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'La etiqueta es requerida'
                : null,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _addressController,
            decoration: const InputDecoration(
              labelText: 'Dirección (Calle y Número)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: 'Notas (Ej: Portón rojo, Apto 3B)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.notes_outlined),
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 16),
          Text(
            'Coordenadas (Opcional)',
            style: textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Botón GPS
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isButtonDisabled ? null : _getUserLocation,
                  icon: _isGettingLocation
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location, size: 18),
                  label: const Text('Mi Ubicación'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.primary,
                    side: BorderSide(
                      color: colorScheme.primary.withOpacity(0.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Botón MAPA
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isButtonDisabled ? null : _openMapPicker,
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: const Text('Ver Mapa'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.secondary,
                    side: BorderSide(
                      color: colorScheme.secondary.withOpacity(0.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _latController,
                  decoration: const InputDecoration(
                    labelText: 'Latitud',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _lngController,
                  decoration: const InputDecoration(
                    labelText: 'Longitud',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _gmapsController,
            decoration: const InputDecoration(
              labelText: 'URL Google Maps (Opcional)',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: isButtonDisabled ? null : _submit,
            icon: _isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.onPrimary,
                    ),
                  )
                : const Icon(Icons.save),
            label: Text(isEditMode ? 'Guardar Cambios' : 'Añadir Dirección'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
    // --- FIN DE CAMBIO ---
  }
}
