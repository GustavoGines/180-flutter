import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/models/user.dart';
import '../../core/network/dio_client.dart';

// Se define el provider aquí para que sea accesible globalmente
final authRepoProvider = Provider<AuthRepository>((ref) => AuthRepository());

class AuthRepository {
  final Dio _dio = DioClient().dio;
  final _storage = const FlutterSecureStorage();

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
      // Re-inicializamos Dio para que use el nuevo token en las siguientes peticiones
      await init();
      return true;
    }
    return false;
  }

  // Obtiene los datos del usuario actualmente autenticado
  Future<AppUser> me() async {
    final res = await _dio.get('/me');
    return AppUser.fromJson(res.data as Map<String, dynamic>);
  }

  // Cierra la sesión en el backend y borra el token local
  Future<void> logout() async {
    try {
      // Llama a la ruta /logout de tu API Laravel
      await _dio.post('/logout');
    } catch (e) {
      // Incluso si la API falla, deslogueamos localmente
      print('API logout call failed, logging out locally anyway: $e');
    } finally {
      // Siempre borra el token del almacenamiento seguro
      await _storage.delete(key: 'auth_token');
    }
  }

  // Lee el token desde el almacenamiento seguro
  Future<String?> getToken() async {
    return await _storage.read(key: 'auth_token');
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
        print('Error en forgotPassword: $e');
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
      print('Error en resetPassword: $e');
      return false;
    }
  }
}
