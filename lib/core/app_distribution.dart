import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pasteleria_180_flutter/core/config.dart'
    show kFlavor; // <- usar el de config.dart

const _channel = MethodChannel('app_distribution');

Future<bool> checkTesterUpdate() async {
  if (kIsWeb || !Platform.isAndroid) return false;
  if (kFlavor != 'dev') return false; // gate por flavor

  try {
    final hasUpdate = await _channel.invokeMethod<bool>('checkForUpdate');
    return hasUpdate ?? false;
  } on MissingPluginException {
    return false; // canal no registrado (ej. prod)
  } on PlatformException {
    return false;
  }
}
