import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasteleria_180_flutter/core/models/user.dart';
import 'package:pasteleria_180_flutter/core/network/dio_client.dart';
import 'package:pasteleria_180_flutter/core/network/validation_exception.dart';

// Provider para el repositorio
final usersRepoProvider = Provider<UsersRepository>((ref) => UsersRepository());

// Provider para obtener la lista de usuarios (para el panel de admin)
// AHORA ES UN .family para poder pasar un query de búsqueda
final usersListProvider = FutureProvider.autoDispose
    .family<List<AppUser>, String>((ref, query) {
      // Si el query está vacío, usamos el provider sin query
      // Si tiene algo, lo pasamos al método
      return ref
          .watch(usersRepoProvider)
          .getUsers(query: query.isEmpty ? null : query);
    });

// NUEVO: Provider para obtener los detalles de UN solo usuario
final userDetailsProvider = FutureProvider.autoDispose.family<AppUser, int>((
  ref,
  id,
) {
  return ref.watch(usersRepoProvider).getUserById(id);
});

// 🎯 NUEVO Provider para la Papelera
final trashedUsersProvider = FutureProvider.autoDispose<List<AppUser>>((ref) {
  return ref.watch(usersRepoProvider).getTrashedUsers();
});

class UsersRepository {
  final Dio _dio = DioClient().dio;

  /// GET /users
  /// Obtiene la lista de todos los usuarios (para admin)
  Future<List<AppUser>> getUsers({String? query}) async {
    // Prepara los queryParameters
    Map<String, dynamic>? queryParameters;
    if (query != null && query.isNotEmpty) {
      queryParameters = {'query': query};
    }

    final res = await _dio.get('/users', queryParameters: queryParameters);
    final body = res.data;

    List rows;
    // Asumimos paginación de Laravel
    if (body is Map && body['data'] is List) {
      rows = body['data'];
    }
    // Fallback si no viene paginado
    else if (body is List) {
      rows = body;
    } else {
      rows = const [];
    }

    return rows
        .whereType<Map>()
        .map<Map<String, dynamic>>(
          (m) => m.map((k, v) => MapEntry(k.toString(), v)),
        )
        .map(AppUser.fromJson)
        .toList();
  }

  /// GET /users/{id}
  /// Obtiene un usuario específico por ID
  Future<AppUser> getUserById(int id) async {
    final res = await _dio.get('/users/$id');
    final body = res.data;

    late final Map<String, dynamic> map;
    if (body is Map && body['data'] is Map) {
      map = (body['data'] as Map).map((k, v) => MapEntry(k.toString(), v));
    } else if (body is Map) {
      map = body.map((k, v) => MapEntry(k.toString(), v));
    } else {
      throw Exception('Respuesta inesperada al buscar usuario');
    }
    return AppUser.fromJson(map);
  }

  /// POST /users
  /// Crea un nuevo usuario (admin o staff)
  Future<AppUser> createUser({
    required String name,
    required String email,
    required String password,
    required String role, // 'admin' | 'staff'
  }) async {
    try {
      final res = await _dio.post(
        '/users',
        data: {
          'name': name,
          'email': email,
          'password': password,
          'password_confirmation': password,
          'role': role,
        },
      );

      // Devolvemos el AppUser creado, en lugar de un Map
      final body = res.data;
      late final Map<String, dynamic> map;

      if (body is Map && body['data'] is Map) {
        map = (body['data'] as Map).map((k, v) => MapEntry(k.toString(), v));
      } else if (body is Map) {
        map = body.map((k, v) => MapEntry(k.toString(), v));
      } else {
        throw Exception('Respuesta inesperada al crear usuario');
      }
      return AppUser.fromJson(map);
    } on DioException catch (e) {
      // Analizamos si el error es de Validación (422) o Conflicto (409)
      final statusCode = e.response?.statusCode;
      final responseData = e.response?.data;

      // 1. Manejo de Conflictos (409 - Posiblemente soft-delete/Papelera)
      if (statusCode == 409 &&
          responseData is Map &&
          responseData.containsKey('user')) {
        // El usuario existe pero está en soft-delete.
        // Relanzamos el DioException para que la UI pueda atraparlo y mostrar
        // un diálogo de restauración (similar a la lógica de clientes).
        rethrow;
      }

      // 2. Manejo de Errores de Validación (422)
      if (statusCode == 422 &&
          responseData is Map &&
          responseData.containsKey('errors')) {
        // Extraer el map de errores (ej: {"email": ["validation.unique"]})
        final Map<String, dynamic> errors = (responseData['errors'] as Map).map(
          (k, v) => MapEntry(k.toString(), v),
        );
        // Relanzamos nuestra excepción personalizada con los errores
        throw ValidationException(errors);
      }

      // 3. Otros errores de red o servidor
      rethrow;
    }
  }

  /// PUT /users/{id}
  /// Actualiza un usuario (nombre, email, rol)
  Future<AppUser> updateUser(int id, Map<String, dynamic> payload) async {
    // No permitimos cambiar la contraseña desde este endpoint
    // (eso debería tener su propio flujo)
    payload.remove('password');
    payload.remove('password_confirmation');

    final res = await _dio.put('/users/$id', data: payload);

    final body = res.data;
    late final Map<String, dynamic> map;

    if (body is Map && body['data'] is Map) {
      map = (body['data'] as Map).map((k, v) => MapEntry(k.toString(), v));
    } else if (body is Map) {
      map = body.map((k, v) => MapEntry(k.toString(), v));
    } else {
      throw Exception('Respuesta inesperada al actualizar usuario');
    }
    return AppUser.fromJson(map);
  }

  /// DELETE /users/{id}
  /// Elimina un usuario (soft delete)
  Future<void> deleteUser(int id) async {
    try {
      await _dio.delete('/users/$id');
    } catch (e) {
      debugPrint('Error en deleteUser: $e');
      rethrow;
    }
  }

  // 🎯 NUEVO: GET /users/trashed
  /// Obtiene la lista de usuarios en la papelera (soft-deleted)
  Future<List<AppUser>> getTrashedUsers() async {
    final res = await _dio.get('/users/trashed');
    final body = res.data;

    List rows = body is Map && body['data'] is List
        ? body['data']
        : (body is List ? body : const []);

    return rows
        .whereType<Map>()
        .map<Map<String, dynamic>>(
          (m) => m.map((k, v) => MapEntry(k.toString(), v)),
        )
        .map(AppUser.fromJson)
        .toList();
  }

  // 🎯 NUEVO: POST /users/{id}/restore
  /// Restaura un usuario soft-deleted.
  Future<AppUser> restoreUser(int id) async {
    final res = await _dio.post('/users/$id/restore');

    final body = res.data;
    late final Map<String, dynamic> map;

    if (body is Map && body['data'] is Map) {
      map = (body['data'] as Map).map((k, v) => MapEntry(k.toString(), v));
    } else if (body is Map) {
      map = body.map((k, v) => MapEntry(k.toString(), v));
    } else {
      throw Exception('Respuesta inesperada al restaurar usuario');
    }
    return AppUser.fromJson(map);
  }

  // 🎯 NUEVO: DELETE /users/{id}/force-delete
  /// Elimina permanentemente un usuario de la base de datos.
  Future<void> forceDeleteUser(int id) async {
    try {
      await _dio.delete('/users/$id/force-delete');
    } catch (e) {
      debugPrint('Error en forceDeleteUser: $e');
      rethrow;
    }
  }
}
