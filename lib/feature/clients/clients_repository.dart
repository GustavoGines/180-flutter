import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/dio_client.dart';
import '../../core/models/client.dart';
import '../../core/models/client_address.dart'; // <-- IMPORTAR MODELO

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

    late final Map<String, dynamic> map;

    if (body is Map && body['data'] is Map) {
      map = (body['data'] as Map).map((k, v) => MapEntry(k.toString(), v));
    } else if (body is Map) {
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
    try {
      final res = await _dio.get('/clients/$id');
      final body = res.data;

      late final Map<String, dynamic> map;
      if (body is Map && body['data'] is Map) {
        map = (body['data'] as Map).map((k, v) => MapEntry(k.toString(), v));
      } else if (body is Map) {
        map = body.map((k, v) => MapEntry(k.toString(), v));
      } else {
        throw Exception(
          'Respuesta inesperada al buscar cliente: ${body.runtimeType}',
        );
      }
      // Gracias al modelo actualizado, esto YA INCLUIRÁ las 'addresses'
      return Client.fromJson(map);
    } catch (e) {
      debugPrint('Error en getClientById: $e');
      return null;
    }
  }

  /// PUT /clients/{id}
  Future<Client> updateClient(int id, Map<String, dynamic> payload) async {
    final res = await _dio.put('/clients/$id', data: payload);
    final body = res.data;

    late final Map<String, dynamic> map;
    if (body is Map && body['data'] is Map) {
      map = (body['data'] as Map).map((k, v) => MapEntry(k.toString(), v));
    } else if (body is Map) {
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
      await _dio.delete('/clients/$id');
    } catch (e) {
      debugPrint('Error en deleteClient: $e');
      rethrow;
    }
  }

  /// GET /clients/trashed
  Future<List<Client>> getTrashedClients() async {
    // ... (tu código está perfecto) ...
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
    // ... (tu código está perfecto) ...
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

  /// DELETE /clients/{id}/force-delete
  Future<void> forceDeleteClient(int id) async {
    // ... (tu código está perfecto) ...
    try {
      await _dio.delete('/clients/$id/force-delete');
    } catch (e) {
      debugPrint('Error en forceDeleteClient: $e');
      rethrow;
    }
  }

  // ---- 👇 NUEVOS MÉTODOS PARA DIRECCIONES 👇 ----

  /// POST /clients/{clientId}/addresses
  /// Añade una nueva dirección a un cliente específico.
  Future<ClientAddress> addAddress(
    int clientId,
    Map<String, dynamic> payload,
  ) async {
    // Asegurarnos que el payload NO envíe el ID del cliente,
    // ya que va en la URL. El backend lo asignará.
    payload.remove('client_id');

    final res = await _dio.post('/clients/$clientId/addresses', data: payload);

    // Asumimos que la API devuelve { "data": {...} }
    final body = res.data;
    if (body is Map && body['data'] is Map) {
      final map = (body['data'] as Map).map(
        (k, v) => MapEntry(k.toString(), v),
      );
      return ClientAddress.fromJson(map);
    }
    // Fallback por si devuelve el objeto directo
    else if (body is Map) {
      final map = body.map((k, v) => MapEntry(k.toString(), v));
      return ClientAddress.fromJson(map);
    } else {
      throw Exception('Respuesta inesperada al crear dirección');
    }
  }

  /// PUT /client-addresses/{addressId}
  /// Actualiza una dirección específica.
  Future<ClientAddress> updateAddress(
    int addressId,
    Map<String, dynamic> payload,
  ) async {
    // Laravel usa PUT, así que enviamos el payload completo
    final res = await _dio.put('/client-addresses/$addressId', data: payload);

    final body = res.data;
    if (body is Map && body['data'] is Map) {
      final map = (body['data'] as Map).map(
        (k, v) => MapEntry(k.toString(), v),
      );
      return ClientAddress.fromJson(map);
    } else if (body is Map) {
      final map = body.map((k, v) => MapEntry(k.toString(), v));
      return ClientAddress.fromJson(map);
    } else {
      throw Exception('Respuesta inesperada al actualizar dirección');
    }
  }

  /// DELETE /client-addresses/{addressId}
  /// Elimina una dirección específica.
  Future<void> deleteAddress(int addressId) async {
    try {
      await _dio.delete('/client-addresses/$addressId');
    } catch (e) {
      debugPrint('Error en deleteAddress: $e');
      rethrow;
    }
  }
}
