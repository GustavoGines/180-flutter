// NUEVO ARCHIVO: lib/features/clients/presentation/widgets/map_picker_page.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

/// Un selector de mapa visual a pantalla completa.
/// Devuelve el `LatLng` seleccionado al hacer pop.
class MapPickerPage extends StatefulWidget {
  final LatLng? initialCoordinates;

  const MapPickerPage({super.key, this.initialCoordinates});

  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  // Un set de coordenadas por defecto (puedes cambiarlo a tu ciudad)
  static const LatLng _defaultCenter = LatLng(-26.1775, -58.1756); // Formosa

  late LatLng _currentPinPosition;
  GoogleMapController? _mapController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentPinPosition = widget.initialCoordinates ?? _defaultCenter;
    _determineInitialPosition();
  }

  /// Intenta centrar el mapa en la ubicación actual del usuario si no hay
  /// coordenadas iniciales. Si falla, usa el default.
  Future<void> _determineInitialPosition() async {
    if (widget.initialCoordinates != null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Servicio de GPS desactivado');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Permiso denegado');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Permiso denegado permanentemente');
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      _currentPinPosition = LatLng(position.latitude, position.longitude);
    } catch (e) {
      // Si algo falla (permiso, GPS apagado), usa el default
      _currentPinPosition = _defaultCenter;
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        // Mueve la cámara a la posición determinada
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(_currentPinPosition, 16.0),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seleccionar Ubicación')),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentPinPosition,
              zoom: 15.0,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              // Si ya determinamos la posición (en initState), mover la cámara
              if (!_isLoading) {
                controller.animateCamera(
                  CameraUpdate.newLatLngZoom(_currentPinPosition, 16.0),
                );
              }
            },
            // Al mover la cámara, actualizamos la posición del "pin"
            onCameraMove: (CameraPosition position) {
              _currentPinPosition = position.target;
            },
            myLocationButtonEnabled: true,
            myLocationEnabled: true,
            zoomControlsEnabled: false,
          ),

          // Pin/Marcador Fijo en el Centro de la Pantalla
          Center(
            child: Padding(
              // Pequeño ajuste para que la base del pin apunte al centro
              padding: const EdgeInsets.only(bottom: 48.0),
              child: Icon(
                Icons.location_pin,
                size: 48.0,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),

          // Botón para confirmar la selección
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding:
                  const EdgeInsets.all(24.0) +
                  EdgeInsets.only(
                    bottom: MediaQuery.of(context).padding.bottom,
                  ),
              child: FilledButton.icon(
                icon: const Icon(Icons.check),
                label: const Text('Seleccionar esta ubicación'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  textStyle: Theme.of(context).textTheme.titleMedium,
                ),
                onPressed: () {
                  // Devuelve la posición del pin al cerrar la pantalla
                  Navigator.of(context).pop(_currentPinPosition);
                },
              ),
            ),
          ),

          // Indicador de carga inicial
          if (_isLoading)
            Container(
              color: Colors.white.withOpacity(0.5),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
