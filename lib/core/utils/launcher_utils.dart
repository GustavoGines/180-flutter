// lib/core/utils/launcher_utils.dart
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Lanza una URL externa de forma segura (para WhatsApp, emails, etc.)
Future<void> launchExternalUrl(String url) async {
  final Uri uri = Uri.parse(url);
  try {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (kDebugMode) {
        print('No se pudo abrir la URL: $url');
      }
    }
  } catch (e) {
    if (kDebugMode) {
      print('Error al intentar abrir la URL: $e');
    }
  }
}

// --- 👇 FUNCIÓN MODIFICADA ---

/// Abre Google Maps y busca la dirección O las coordenadas.
Future<void> launchGoogleMaps(String addressOrCoords) async {
  if (addressOrCoords.isEmpty) return;

  // 1. RegEx para detectar si el string son coordenadas.
  //    Busca: (opcional -)(números)(.)(números)(,)(opcional espacio)(opcional -)(números)(.)(números)
  final isCoords = RegExp(
    r'^-?[\d\.]+,\s*-?[\d\.]+$',
  ).hasMatch(addressOrCoords);

  String query;

  if (isCoords) {
    // 2. Si son coordenadas (ej: "-26.18, -58.17"), el query es directo
    if (kDebugMode) {
      print("Detectadas Coordenadas: $addressOrCoords");
    }
    query = addressOrCoords;
  } else {
    // 3. Si es una dirección (ej: "Av. 25 de Mayo 123"), se codifica
    if (kDebugMode) {
      print("Detectada Dirección: $addressOrCoords");
    }
    query = Uri.encodeComponent(addressOrCoords);
  }

  // 4. Se construye la URL universal de Google Maps
  //    (funciona tanto para 'lat,lng' como para 'texto de dirección')
  final Uri mapUrl = Uri.parse(
    'https://www.google.com/maps/search/?api=1&query=$query',
  );

  // 5. Usa la función que ya tenías
  await launchExternalUrl(mapUrl.toString());
}
