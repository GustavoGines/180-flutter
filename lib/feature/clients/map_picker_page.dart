// NUEVO ARCHIVO: lib/features/clients/presentation/widgets/map_picker_page.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

// --- ESTILO JSON PARA EL MAPA OSCURO ---
// Este es un estilo estándar "oscuro" de Google.
const String _darkMapStyle = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#242f3e"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#242f3e"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#746855"}]},
  {"featureType": "administrative.locality", "elementType": "labels.text.fill", "stylers": [{"color": "#d59563"}]},
  {"featureType": "poi", "elementType": "labels.text.fill", "stylers": [{"color": "#d59563"}]},
  {"featureType": "poi.park", "elementType": "geometry", "stylers": [{"color": "#263c3f"}]},
  {"featureType": "poi.park", "elementType": "labels.text.fill", "stylers": [{"color": "#6b9a76"}]},
  {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#38414e"}]},
  {"featureType": "road", "elementType": "geometry.stroke", "stylers": [{"color": "#212a37"}]},
  {"featureType": "road", "elementType": "labels.text.fill", "stylers": [{"color": "#9ca5b3"}]},
  {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#746855"}]},
  {"featureType": "road.highway", "elementType": "geometry.stroke", "stylers": [{"color": "#1f2835"}]},
  {"featureType": "road.highway", "elementType": "labels.text.fill", "stylers": [{"color": "#f3d19c"}]},
  {"featureType": "transit", "elementType": "geometry", "stylers": [{"color": "#2f3948"}]},
  {"featureType": "transit.station", "elementType": "labels.text.fill", "stylers": [{"color": "#d59563"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#17263c"}]},
  {"featureType": "water", "elementType": "labels.text.fill", "stylers": [{"color": "#515c6d"}]},
  {"featureType": "water", "elementType": "labels.text.stroke", "stylers": [{"color": "#17263c"}]}
]
''';
// --- FIN DEL ESTILO JSON ---

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
    // --- OBTENER DATOS DEL TEMA ---
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;
    final bool isDarkMode = theme.brightness == Brightness.dark;
    // --- FIN ---

    return Scaffold(
      // --- APPBAR ADAPTADA ---
      appBar: AppBar(
        title: const Text('Seleccionar Ubicación'),
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 1,
        titleTextStyle: tt.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: cs.onSurface,
        ),
      ),
      // --- FIN APPBAR ---
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentPinPosition,
              zoom: 15.0,
            ),
            onMapCreated: (controller) {
              _mapController = controller;

              // --- APLICAR ESTILO OSCURO SI ES NECESARIO ---
              if (isDarkMode) {
                controller.setMapStyle(_darkMapStyle);
              }
              // --- FIN ---

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
                // Esto ya estaba bien, usa el color primario del tema
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
                // Esto ya estaba bien, usa el estilo por defecto del tema
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
              // --- OVERLAY ADAPTADO AL TEMA ---
              color: cs.surface.withOpacity(0.5),
              // --- FIN ---
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
