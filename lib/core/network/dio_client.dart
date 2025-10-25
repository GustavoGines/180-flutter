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

  Future<void> init() async {
    dio.interceptors.clear();
    // Logger SOLO si lo pedís por flag o si estás en debug
    if (kLogHttp || kDebugMode) {
      dio.interceptors.add(
        PrettyDioLogger(
          requestHeader: false, // evita imprimir Authorization
          requestBody: true,
          responseHeader: false,
          responseBody: true,
          error: true,
          compact: true,
        ),
      );
    }

    // Auth interceptor
    dio.interceptors.add(AuthInterceptor(storage));

    // Logger (podés desactivarlo en prod si querés)
    dio.interceptors.add(
      PrettyDioLogger(
        requestHeader: true,
        requestBody: true,
        responseHeader: false,
        responseBody: true,
        error: true,
        compact: true,
      ),
    );
  }
}
