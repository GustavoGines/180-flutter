// lib/core/network/auth_interceptor.dart

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthInterceptor extends Interceptor {
  final FlutterSecureStorage storage;
  AuthInterceptor(this.storage);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await storage.read(key: 'auth_token');
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    // ✅ CORRECCIÓN:
    // Llamar a handler.next() DESPUÉS de que el await se complete.
    // NO usar super.onRequest().
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      final path = err.requestOptions.path;

      if (!path.contains('/auth/') && !path.contains('/ping')) {
        final token = await storage.read(key: 'auth_token');
        if (token != null && token.isNotEmpty) {
          await storage.delete(key: 'auth_token');
        }
      }
    }

    // ✅ BUENA PRÁCTICA:
    // Usar handler.next() también en onError.
    handler.next(err);
  }
}
