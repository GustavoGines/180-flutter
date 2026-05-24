// lib/app_distribution.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_app_distribution_platform_interface/firebase_app_distribution_platform_interface.dart';
import 'package:pasteleria_180_flutter/core/config.dart' show kFlavor;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _fad = FirebaseAppDistributionPlatform.instance;

/// 🔍 Comprueba si hay una nueva versión disponible.
/// [interactive] Si es true, intentará loguear al tester si no está logueado.
/// Si es false, simplemente saldrá si el tester no está logueado.
Future<bool> checkTesterUpdate({
  bool interactive = false,
  bool checkOnly = false, // <-- AÑADIDO
}) async {
  if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return false;

  const allow = kDebugMode || kFlavor == 'dev';
  if (!allow) return false;

  try {
    debugPrint(
      "🧭 [AppDist] Iniciando chequeo (Interactivo: $interactive, CheckOnly: $checkOnly)...",
    );

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

    // --- LÓGICA DE DETECCIÓN FINALIZADA (HAY UPDATE) ---

    // Si solo queríamos chequear, devolvemos true y NO iniciamos la UI de descarga nativa
    if (checkOnly) {
      debugPrint(
        "ℹ️ [AppDist] Nueva versión detectada (CheckOnly). Retornando true.",
      );
      return true;
    }

    debugPrint(
      "⬇️ [AppDist] Nueva versión disponible. Iniciando descarga (Nativa)…",
    );
    await _fad.updateIfNewReleaseAvailable();
    debugPrint("✅ [AppDist] Actualización completada (Nativa).");
    return true;
  } catch (e) {
    debugPrint("❌ [AppDist] Error en checkTesterUpdate: $e");
    return false;
  }
}

/// Inicia el flujo nativo de actualización (descarga e instalación).
Future<void> startUpdate() async {
  try {
    await _fad.updateIfNewReleaseAvailable();
  } catch (e) {
    debugPrint("❌ [AppDist] Error iniciando update: $e");
  }
}

Future<bool> maybeShowTesterExplainerOnce(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  const key = 'fad_explainer_shown';
  final alreadyShown = prefs.getBool(key) ?? false;

  if (alreadyShown) {
    debugPrint('ℹ️ Modo de prueba ya activado previamente.');
    return true;
  }

  if (!context.mounted) return false;

  // Usamos 'context' que ahora recibimos por parámetro
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('Activar Modo de Prueba'),
      content: RichText(
        text: TextSpan(
          // 1. Usa el estilo del tema del diálogo
          style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                height: 1.4, // Ajusta el interlineado si lo deseas
              ),
          children: const [
            TextSpan(
              text: 'Bienvenido/a a la versión de pruebas de 180° App.\n\n'
                  'Para recibir actualizaciones automáticas y avisos de nuevas '
                  'versiones, es necesario habilitar el ',
            ),
            TextSpan(
              text: 'Modo de Prueba',
              // 2. La negrita ahora será visible
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(
              text: ' por única vez.\n\n'
                  'Se te pedirá iniciar sesión con tu cuenta de Google y aceptar '
                  'las notificaciones de la app.',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Más tarde'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Activar ahora'),
        ),
      ],
    ),
  );

  if (ok == true) {
    await prefs.setBool(key, true);
    debugPrint('✅ Modo de prueba activado y guardado.');
    return true;
  }

  debugPrint('🚫 Usuario pospuso la activación del modo de prueba.');
  return false;
}
