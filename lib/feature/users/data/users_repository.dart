import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasteleria_180_flutter/core/models/user.dart';
import 'package:pasteleria_180_flutter/core/network/dio_client.dart';

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
}
