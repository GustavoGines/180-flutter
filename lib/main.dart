import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pasteleria_180_flutter/core/config.dart';
import 'app.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:pasteleria_180_flutter/core/network/dio_client.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

Future<void> pingApi() async {
  try {
    final dio = DioClient().dio;
    // Usa un endpoint simple: si tu API base es /api, probá '/'
    final res = await dio.get('/');
    debugPrint('PING API → HTTP ${res.statusCode}');
  } catch (e) {
    debugPrint('PING API ERROR → $e');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting('es_AR', null);

  // Verificar que en release entró el API_BASE
  debugPrint('CONFIG → FLAVOR=$kFlavor  API_BASE=$kApiBase');

  // 👇 Inicializá el cliente y logueá su baseUrl real
  await DioClient().init();
  debugPrint('DIO baseUrl → ${DioClient().dio.options.baseUrl}');

  // Ejecutá el ping SOLO si:
  // - estás en dev, y
  // - activaste el flag, o estás en debug
  if (kFlavor == 'dev' && (kEnablePing || kDebugMode)) {
    // no bloquees el arranque
    // ignore: discarded_futures
    pingApi();
  }

  runApp(const ProviderScope(child: One80App()));
}
