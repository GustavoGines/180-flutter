// address_form_dialog.dart (CON CAMBIOS)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/snackbar_helper.dart';
import 'package:pasteleria_180_flutter/core/models/client_address.dart';
// Asegúrate de que esta ruta sea correcta según tu estructura
import 'package:pasteleria_180_flutter/feature/clients/clients_repository.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

// --- NUEVO IMPORT ---
import 'package:google_maps_flutter/google_maps_flutter.dart'; // Para LatLng
import 'map_picker_page.dart'; // La nueva pantalla
import 'package:geocoding/geocoding.dart' as geocoding;

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



  Future<void> _getUserLocation() async {
    setState(() => _isGettingLocation = true);
    try {
      var status = await Permission.locationWhenInUse.request();
      if (status.isGranted) {
        bool isLocationServiceEnabled =
            await Geolocator.isLocationServiceEnabled();
        if (!isLocationServiceEnabled) {
          if (mounted) {
            context.showCustomSnackbar(
              'Por favor, activa el GPS de tu dispositivo.',
              isError: true,
            );
          }
          setState(() => _isGettingLocation = false);
          return;
        }
        
        Position position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        ).timeout(const Duration(seconds: 15), onTimeout: () {
          throw Exception("Tiempo de espera agotado al buscar el GPS.");
        });

        await _processCoordinates(position.latitude, position.longitude);
        if (mounted) context.showCustomSnackbar('Ubicación obtenida con éxito.');
      } else if (status.isDenied || status.isPermanentlyDenied) {
        if (mounted) context.showCustomSnackbar('Permiso de ubicación denegado.', isError: true);
        if (status.isPermanentlyDenied) {
          await openAppSettings();
        }
      }
    } catch (e) {
      if (mounted) context.showCustomSnackbar('Error al obtener la ubicación: $e', isError: true);
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
      await _processCoordinates(selectedLocation.latitude, selectedLocation.longitude);
      if (mounted) context.showCustomSnackbar('Ubicación seleccionada desde el mapa.');
    }
  }

  Future<void> _processCoordinates(double lat, double lng) async {
    _latController.text = lat.toStringAsFixed(7);
    _lngController.text = lng.toStringAsFixed(7);

    // Autocompletar URL Google Maps
    if (_gmapsController.text.isEmpty || _gmapsController.text.contains('maps.google.com/?q=')) {
      _gmapsController.text = 'https://maps.google.com/?q=$lat,$lng';
    }

    // Magia: Reverse Geocoding
    try {
      List<geocoding.Placemark> placemarks = await geocoding
          .placemarkFromCoordinates(lat, lng)
          .timeout(const Duration(seconds: 10));
          
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final street = p.thoroughfare ?? '';
        final number = p.subThoroughfare ?? '';
        
        if (street.isNotEmpty) {
          String fullAddress = street;
          if (number.isNotEmpty) fullAddress += ' $number';
          
          if (_addressController.text.trim().isEmpty) {
             _addressController.text = fullAddress;
             if (mounted) context.showCustomSnackbar('¡Dirección autocompletada mágicamente!');
          }
        }
      }
    } catch (e) {
       debugPrint("Error reverse geocoding: $e");
    }
  }

  Future<void> _submit() async {
    debugPrint('DEBUG: _submit called');
    if (!(_formKey.currentState?.validate() ?? false)) {
      debugPrint('DEBUG: Form validation failed');
      return;
    }

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
    debugPrint('DEBUG: Payload to send: $payload');

    try {
      final repo = ref.read(clientsRepoProvider);
      if (isEditMode) {
        debugPrint('DEBUG: Updating address');
        await repo.updateAddress(
          widget.clientId,
          widget.addressToEdit!.id,
          payload,
        );
      } else {
        debugPrint('DEBUG: Creating address');
        await repo.createAddress(widget.clientId, payload);
      }
      debugPrint('DEBUG: Address operation successful');

      ref.invalidate(clientDetailsProvider(widget.clientId));

      if (mounted) {
        try {
          context.showCustomSnackbar(
            isEditMode
                ? 'Dirección actualizada'
                : 'Dirección añadida con éxito',
          );
        } catch (e) {
          debugPrint('Error mostrando snackbar: $e');
        }
        if (mounted) {
          debugPrint('DEBUG: Popping dialog');
          Navigator.of(context).pop();
        }
      }
    } catch (e, stack) {
      debugPrint('DEBUG: Error in _submit: $e');
      debugPrint('DEBUG: Stack trace: $stack');
      if (mounted) context.showCustomSnackbar('Error al guardar: $e', isError: true);
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
              labelText: 'Dirección (Calle y Número) *',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
            textCapitalization: TextCapitalization.sentences,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'La dirección es obligatoria'
                : null,
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
            minLines: 1,
            maxLines: 4,
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
                ),
              ),
              const SizedBox(width: 8),
              // Botón MAPA
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isButtonDisabled ? null : _openMapPicker,
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: const Text('Ver Mapa'),
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
            validator: (v) {
              if (v == null || v.trim().isEmpty) return null;
              final RegExp urlRegex = RegExp(
                r'^(https?:\/\/)?([\w\d\-_]+\.)+[a-zA-Z]{2,}(:\d+)?(\/.*)?$',
                caseSensitive: false,
              );
              if (!urlRegex.hasMatch(v.trim())) {
                return 'Ingresa una URL válida';
              }
              return null;
            },
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
