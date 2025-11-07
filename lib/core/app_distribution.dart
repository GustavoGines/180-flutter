// lib/app_distribution.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_app_distribution_platform_interface/firebase_app_distribution_platform_interface.dart';
import 'package:pasteleria_180_flutter/core/config.dart' show kFlavor;

final _fad = FirebaseAppDistributionPlatform.instance;

/// 🔍 Comprueba si hay una nueva versión disponible.
/// [interactive] Si es true, intentará loguear al tester si no está logueado.
/// Si es false, simplemente saldrá si el tester no está logueado.
Future<bool> checkTesterUpdate({bool interactive = false}) async {
  if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return false;

  final allow = kDebugMode || kFlavor == 'dev';
  if (!allow) return false;

  try {
    debugPrint("🧭 [AppDist] Iniciando chequeo (Interactivo: $interactive)...");

    final isSignedIn = await _fad.isTesterSignedIn();
    if (!isSignedIn) {
      if (interactive) {
        debugPrint(
          "👤 [AppDist] No logueado. Mostrando 'Activar modo de prueba'...",
        );
        await _fad.signInTester();
      } else {
        debugPrint("👤 [AppDist] No logueado (chequeo silencioso). Omitiendo.");
        return false;
      }
    }

    final hasUpdate = await _fad.isNewReleaseAvailable();
    if (!hasUpdate) {
      debugPrint("✅ [AppDist] No hay nueva versión disponible.");
      return false;
    }

    debugPrint("⬇️ [AppDist] Nueva versión disponible. Iniciando descarga…");
    await _fad.updateIfNewReleaseAvailable();
    debugPrint("✅ [AppDist] Actualización completada.");
    return true;
  } catch (e) {
    debugPrint("❌ [AppDist] Error en checkTesterUpdate: $e");
    return false;
  }
}
