import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_interceptor.dart';
import 'package:pasteleria_180_flutter/core/config.dart'; // ← usa kApiBase central

import 'package:flutter/material.dart';
import 'package:pasteleria_180_flutter/core/utils/snackbar_helper.dart';

class DioClient {
  static final DioClient _instance = DioClient._internal();
  factory DioClient() => _instance;

  late final Dio dio;
  final storage = const FlutterSecureStorage();

  DioClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: kApiBase, // ← usa kApiBase central
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
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
          if (e.type == DioExceptionType.connectionError ||
              e.type == DioExceptionType.connectionTimeout) {
            debugPrint("🌐 Error de red global capturado");
            
            // Mostrar un banner visual si no hay red usando la global key
            globalSnackbarKey.currentState?.showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.wifi_off, color: Colors.white),
                    SizedBox(width: 12),
                    Expanded(child: Text("Sin conexión a internet. Revisa tu red.")),
                  ],
                ),
                backgroundColor: Colors.red.shade800,
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.all(16),
                duration: const Duration(seconds: 4),
              ),
            );
          }
          handler.next(e);
        },
      ),
    );
  }
}
