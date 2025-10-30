import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/dio_client.dart';
import '../../core/models/client.dart';
import 'package:flutter/foundation.dart';

final clientsRepoProvider = Provider<ClientsRepository>(
  (_) => ClientsRepository(),
);

final getTrashedClientsProvider = FutureProvider.autoDispose<List<Client>>((
  ref,
) {
  return ref.watch(clientsRepoProvider).getTrashedClients();
});

class ClientsRepository {
  final Dio _dio = DioClient().dio;

  /// GET /clients?query=
  Future<List<Client>> searchClients(String query) async {
    final res = await _dio.get('/clients', queryParameters: {'query': query});
    final body = res.data;

    List rows;
    if (body is List) {
      rows = body;
    } else if (body is Map && body['data'] is List) {
      rows = body['data'];
    } else {
      rows = const [];
    }

    return rows
        .whereType<Map>() // por si viene dynamic
        .map<Map<String, dynamic>>(
          (m) => m.map((k, v) => MapEntry(k.toString(), v)),
        )
        .map(Client.fromJson)
        .toList();
  }

  /// POST /clients
  Future<Client> createClient(Map<String, dynamic> payload) async {
    final res = await _dio.post('/clients', data: payload);
    final body = res.data;

    // Normalizamos a Map<String, dynamic>
    late final Map<String, dynamic> map;

    if (body is Map && body['data'] is Map) {
      map = (body['data'] as Map).map((k, v) => MapEntry(k.toString(), v));
    }
    // Fallback por si la API devuelve el objeto directamente
    else if (body is Map) {
      map = body.map((k, v) => MapEntry(k.toString(), v));
    } else {
      throw Exception(
        'Respuesta inesperada al crear cliente: ${body.runtimeType}',
      );
    }

    return Client.fromJson(map);
  }

  /// GET /clients/{id}
  Future<Client?> getClientById(int id) async {
    // Nota: Tu API de Laravel debe tener la ruta: Route::get('/clients/{client}', ...);
    // Si tu ruta es /client (singular), cambia '/clients' aquí.
    try {
      final res = await _dio.get('/clients/$id');
      final body = res.data;

      late final Map<String, dynamic> map;
      // Asumimos que la API devuelve { "data": {...} } al buscar por ID
      if (body is Map && body['data'] is Map) {
        map = (body['data'] as Map).map((k, v) => MapEntry(k.toString(), v));
      }
      // O quizás solo devuelve {...}
      else if (body is Map) {
        map = body.map((k, v) => MapEntry(k.toString(), v));
      } else {
        throw Exception(
          'Respuesta inesperada al buscar cliente: ${body.runtimeType}',
        );
      }
      return Client.fromJson(map);
    } catch (e) {
      // Manejar 404 (No encontrado) u otros errores
      debugPrint('Error en getClientById: $e');
      return null;
    }
  }

  // 👇 AÑADE ESTA FUNCIÓN
  /// PUT /clients/{id}
  Future<Client> updateClient(int id, Map<String, dynamic> payload) async {
    // Nota: Tu API de Laravel debe tener la ruta: Route::put('/clients/{client}', ...);
    final res = await _dio.put('/clients/$id', data: payload);
    final body = res.data;

    late final Map<String, dynamic> map;
    // Asumimos que la API devuelve { "data": {...} } al actualizar
    if (body is Map && body['data'] is Map) {
      map = (body['data'] as Map).map((k, v) => MapEntry(k.toString(), v));
    }
    // O quizás solo devuelve {...}
    else if (body is Map) {
      map = body.map((k, v) => MapEntry(k.toString(), v));
    } else {
      throw Exception(
        'Respuesta inesperada al actualizar cliente: ${body.runtimeType}',
      );
    }
    return Client.fromJson(map);
  }

  /// DELETE /clients/{id}
  Future<void> deleteClient(int id) async {
    try {
      // Laravel devolverá 204 No Content, Dio lo interpretará como éxito
      await _dio.delete('/clients/$id');
    } catch (e) {
      debugPrint('Error en deleteClient: $e');
      // Propaga el error para que la UI pueda mostrar un SnackBar
      rethrow;
    }
  }

  /// GET /clients/trashed
  Future<List<Client>> getTrashedClients() async {
    final res = await _dio.get('/clients/trashed');
    final body = res.data;

    List rows;
    if (body is Map && body['data'] is List) {
      rows = body['data'];
    } else {
      rows = const [];
    }

    return rows
        .whereType<Map>()
        .map<Map<String, dynamic>>(
          (m) => m.map((k, v) => MapEntry(k.toString(), v)),
        )
        .map(Client.fromJson)
        .toList();
  }

  /// POST /clients/{id}/restore
  Future<Client> restoreClient(int id) async {
    final res = await _dio.post('/clients/$id/restore');
    final body = res.data;

    late final Map<String, dynamic> map;
    if (body is Map && body['data'] is Map) {
      map = (body['data'] as Map).map((k, v) => MapEntry(k.toString(), v));
    } else if (body is Map) {
      map = body.map((k, v) => MapEntry(k.toString(), v));
    } else {
      throw Exception('Respuesta inesperada al restaurar cliente');
    }
    return Client.fromJson(map);
  }
}
