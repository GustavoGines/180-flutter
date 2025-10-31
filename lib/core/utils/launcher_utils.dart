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

/// 🚀 AÑADE ESTA NUEVA FUNCIÓN 🚀
/// Abre Google Maps y busca la dirección proporcionada.
Future<void> launchGoogleMaps(String address) async {
  if (address.isEmpty) return;

  // Codifica la dirección para que sea segura en una URL
  final String query = Uri.encodeComponent(address);

  // URL universal de Google Maps
  final Uri mapUrl = Uri.parse(
    'https://www.google.com/maps/search/?api=1&query=$query',
  );

  await launchExternalUrl(mapUrl.toString());
}
