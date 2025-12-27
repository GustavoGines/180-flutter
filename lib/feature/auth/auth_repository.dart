import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pasteleria_180_flutter/core/services/firebase_messaging_service.dart';
import '../../core/models/user.dart';
import '../../core/network/dio_client.dart';

// Se define el provider aquí para que sea accesible globalmente
final authRepoProvider = Provider<AuthRepository>((ref) => AuthRepository(ref));

class AuthRepository {
  final Dio _dio = DioClient().dio;
  final _storage = const FlutterSecureStorage();

  final Ref ref;

  AuthRepository(this.ref);

  // Inicializa el cliente Dio (ej. para cargar el token si ya existe)
  Future<void> init() async => DioClient().init();

  Future<bool> login({required String email, required String password}) async {
    // Genera un nombre de dispositivo único para Laravel Sanctum
    final deviceName = '180_flutter-${DateTime.now().millisecondsSinceEpoch}';

    final res = await _dio.post(
      '/auth/token',
      data: {'email': email, 'password': password, 'device_name': deviceName},
    );

    final token = res.data['token'] as String?;
    if (token != null && token.isNotEmpty) {
      await _storage.write(key: 'auth_token', value: token);
      debugPrint('🔐 Token guardado correctamente: $token');
      // Re-inicializamos Dio para que use el nuevo token en las siguientes peticiones
      await init();

      return true;
    } else {
      debugPrint('❌ Error: Token no recibido en la respuesta de login.');
      return false;
    }
  }

  // Obtiene los datos del usuario actualmente autenticado
  Future<AppUser> me() async {
    final res = await _dio.get('/me');
    final body = res.data;

    late final Map<String, dynamic> map;
    if (body is Map && body['data'] is Map) {
      map = (body['data'] as Map).map((k, v) => MapEntry(k.toString(), v));
    } else if (body is Map) {
      // Fallback para estructura vieja
      map = body.map((k, v) => MapEntry(k.toString(), v));
    } else {
      throw Exception('Respuesta inesperada en /me');
    }
    return AppUser.fromJson(map);
  }

  // Cierra la sesión en el backend y borra el token local
  Future<void> logout() async {
    try {
      // ✅ PASO 1: Intentar des-registrar el dispositivo
      final fcmToken = ref.read(fcmTokenProvider);

      if (fcmToken != null && fcmToken.isNotEmpty) {
        await _dio.post(
          '/devices/unregister', // 👈 El nuevo endpoint de Laravel
          data: {'fcm_token': fcmToken},
        );
        debugPrint("📱 Token FCM des-registrado del backend.");
      } else {
        debugPrint("📱 No se encontró token FCM local para des-registrar.");
      }
      // Llama a la ruta /logout de tu API Laravel
      await _dio.post('/logout');
      debugPrint("🔑 Sesión de Sanctum invalidada en el backend.");
    } catch (e) {
      // Incluso si la API falla, deslogueamos localmente
      debugPrint('API logout call failed, logging out locally anyway: $e');
    } finally {
      // Siempre borra el token del almacenamiento seguro
      await _storage.delete(key: 'auth_token');
      debugPrint("🔑 Token eliminado del almacenamiento seguro.");
    }
  }

  // Lee el token desde el almacenamiento seguro
  Future<String?> getToken() async {
    final token = await _storage.read(key: 'auth_token');
    debugPrint('📦 Token leído de SecureStorage: $token');
    return token;
  }

  /// Solicita un enlace de restablecimiento de contraseña.
  /// Devuelve true si la solicitud fue exitosa.
  Future<bool> forgotPassword(String email) async {
    try {
      // Hacemos la petición POST a la API
      final response = await _dio.post(
        '/forgot-password',
        data: {'email': email},
      );
      // La API de Laravel devuelve un status 200 si el proceso se inició bien.
      return response.statusCode == 200;
    } on DioException catch (e) {
      // Imprimimos el error para depuración
      if (kDebugMode) {
        debugPrint('Error en forgotPassword: $e');
      }
      return false;
    }
  }

  /// Restablece la contraseña del usuario usando el token.
  /// Devuelve true si la contraseña se cambió con éxito.
  Future<bool> resetPassword({
    required String token,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    try {
      final response = await _dio.post(
        '/reset-password', // Llama al endpoint que configuramos en Laravel
        data: {
          'token': token,
          'email': email,
          'password': password,
          'password_confirmation': passwordConfirmation,
        },
      );
      // Laravel devuelve un status 200 si el cambio fue exitoso.
      return response.statusCode == 200;
    } on DioException catch (e) {
      // Imprime el error para depuración (ej. token inválido, contraseña corta, etc.)
      debugPrint('Error en resetPassword: $e');
      return false;
    }
  }

  /// POST /api/devices/register
  /// Envía el token FCM del dispositivo al backend para registrarlo.
  Future<void> registerDevice(String fcmToken) async {
    // Detectar la plataforma
    String platform = 'unknown';
    if (kIsWeb) {
      platform = 'web';
    } else if (Platform.isAndroid) {
      platform = 'android';
    } else if (Platform.isIOS) {
      platform = 'ios';
    }

    try {
      await _dio.post(
        '/devices/register',
        data: {'fcm_token': fcmToken, 'platform': platform},
      );
      debugPrint('Token FCM registrado en el backend exitosamente.');
    } on DioException catch (e) {
      // Si el token ya existe (422 o 304), no es un error crítico.
      // Si es un 401 (no logueado), fallará silenciosamente.
      debugPrint('Error al registrar el token FCM: ${e.response?.data}');
    } catch (e) {
      debugPrint('Error inesperado al registrar token FCM: $e');
    }
  }
}
