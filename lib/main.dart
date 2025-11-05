import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pasteleria_180_flutter/core/config.dart';
import 'app.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:pasteleria_180_flutter/core/network/dio_client.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
// ✅ 1. Importa el nuevo servicio
import 'package:pasteleria_180_flutter/core/services/firebase_messaging_service.dart';

Future<void> pingApi() async {
  try {
    final dio = DioClient().dio;
    final res = await dio.get('/ping');
    debugPrint('PING API → HTTP ${res.statusCode} ${res.data}');
  } catch (e) {
    debugPrint('PING API ERROR → $e');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting('es_AR', null);

  debugPrint('CONFIG → FLAVOR=$kFlavor  API_BASE=$kApiBase');

  await DioClient().init();
  debugPrint('DIO baseUrl → ${DioClient().dio.options.baseUrl}');

  if (kFlavor == 'dev' && (kEnablePing || kDebugMode)) {
    // ignore: discarded_futures
    pingApi();
  }

  // ✅ 2. Crear el Contenedor de Riverpod
  // Esto nos da acceso a los providers ANTES de que los widgets se dibujen
  final container = ProviderContainer();

  try {
    // ✅ 3. Inicializar el servicio de notificaciones
    // Esperamos a que pida permiso y envíe el token al backend
    await container.read(firebaseMessagingServiceProvider).init();
    debugPrint('Firebase Messaging Service inicializado.');
  } catch (e) {
    debugPrint('Error al inicializar Firebase Messaging: $e');
  }

  // ✅ 4. Iniciar la App
  // Le pasamos el 'container' que ya creamos para que Riverpod no se reinicie
  runApp(
    UncontrolledProviderScope(container: container, child: const One80App()),
  );
}
