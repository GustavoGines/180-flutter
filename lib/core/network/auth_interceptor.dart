// lib/core/network/auth_interceptor.dart

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthInterceptor extends Interceptor {
  final FlutterSecureStorage storage;
  final Function()? onUnauthorized;

  AuthInterceptor(this.storage, {this.onUnauthorized});

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final token = await storage.read(key: 'auth_token');
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    } catch (e) {
      // Ignorar error de lectura (ej. Keystore corrupto en reinstalación)
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
        try {
          final token = await storage.read(key: 'auth_token');
          if (token != null && token.isNotEmpty) {
            await storage.delete(key: 'auth_token');
            // Disparamos el callback para invalidar el provider y redirigir
            if (onUnauthorized != null) {
              onUnauthorized!();
            }
          }
        } catch (e) {
          // Si hubo error leyendo, igual intentamos borrar y desloguear
          try { await storage.delete(key: 'auth_token'); } catch (_) {}
          if (onUnauthorized != null) {
            onUnauthorized!();
          }
        }
      }
    }

    // ✅ BUENA PRÁCTICA:
    // Usar handler.next() también en onError.
    handler.next(err);
  }
}
