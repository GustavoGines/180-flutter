import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_interceptor.dart';
import 'package:pasteleria_180_flutter/core/config.dart'; // ← usa kApiBase central

class DioClient {
  static final DioClient _instance = DioClient._internal();
  factory DioClient() => _instance;

  late final Dio dio;
  final storage = const FlutterSecureStorage();

  DioClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: kApiBase, // ← usa SIEMPRE la fuente única
        connectTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
        headers: {'Accept': 'application/json'},
      ),
    );
  }

  Future<void> init({Function()? onUnauthorized}) async {
    dio.interceptors.clear();

    // 1. Auth interceptor (SIEMPRE PRIMERO)
    dio.interceptors
        .add(AuthInterceptor(storage, onUnauthorized: onUnauthorized));

    // 2. Logger (SOLO UNO)
    if (kLogHttp || kDebugMode) {
      dio.interceptors.add(
        PrettyDioLogger(
          requestHeader: true, // Ponlo en true si quieres ver el header de Auth
          requestBody: true,
          responseHeader: false,
          responseBody: true,
          error: true,
          compact: true,
        ),
      );
    }

    // 3. Error handler genérico (AL FINAL)
    dio.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException e, handler) {
          if (e.type == DioExceptionType.connectionError) {
            debugPrint("🌐 Sin conexión a internet");
          }
          handler.next(e);
        },
      ),
    );
  }
}
