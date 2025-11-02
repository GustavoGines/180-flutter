import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/dio_client.dart';
import '../../core/models/client.dart';
import '../../core/models/client_address.dart'; // <-- IMPORTAR EL MODELO DE DIRECCIÓN

final clientsRepoProvider = Provider<ClientsRepository>(
  (_) => ClientsRepository(),
);

// Provider para la lista de clientes (con búsqueda)
final clientsListProvider = FutureProvider.autoDispose
    .family<List<Client>, String>((ref, query) {
      return ref.watch(clientsRepoProvider).searchClients(query: query);
    });

// Provider para los detalles de UN cliente
final clientDetailsProvider = FutureProvider.autoDispose.family<Client?, int>((
  ref,
  id,
) {
  return ref.watch(clientsRepoProvider).getClientById(id);
});

// Provider para la lista de clientes borrados (papelera)
final trashedClientsProvider = FutureProvider.autoDispose<List<Client>>((ref) {
  return ref.watch(clientsRepoProvider).getTrashedClients();
});

class ClientsRepository {
  final Dio _dio = DioClient().dio;

  /// GET /clients?query=
  /// Busca clientes por nombre o teléfono
 Future<List<Client>> searchClients({String query = ''}) async {
    final res = await _dio.get('/clients', queryParameters: {'query': query});
    final body = res.data;

    List rows;
    if (body is Map && body['data'] is List) {
      rows = body['data']; // Asumimos paginación
    } else if (body is List) {
      rows = body; // Fallback si no viene paginado
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
  /// Nota: Este endpoint debe devolver el cliente CON sus direcciones
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
      // El Client.fromJson actualizado se encargará de parsear
      // la lista de 'addresses' que venga en el JSON
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

  // --- Papelera (Soft Deletes) ---

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

  /// DELETE /clients/{id}/force-delete
  Future<void> forceDeleteClient(int id) async {
    try {
      await _dio.delete('/clients/$id/force-delete');
    } catch (e) {
      debugPrint('Error en forceDeleteClient: $e');
      rethrow;
    }
  }

  // ======================================================
  // --- AÑADIDO: CRUD DE DIRECCIONES (ClientAddress) ---
  // ======================================================

  /// POST /clients/{clientId}/addresses
  /// Crea una nueva dirección para un cliente
  Future<ClientAddress> createAddress(
    int clientId,
    Map<String, dynamic> payload,
  ) async {
    final res = await _dio.post('/clients/$clientId/addresses', data: payload);

    // Asumimos que la API devuelve la dirección creada
    // envuelta en 'data'
    final body = res.data;
    late final Map<String, dynamic> map;

    if (body is Map && body['data'] is Map) {
      map = (body['data'] as Map).map((k, v) => MapEntry(k.toString(), v));
    } else if (body is Map) {
      map = body.map((k, v) => MapEntry(k.toString(), v));
    } else {
      throw Exception('Respuesta inesperada al crear dirección');
    }
    return ClientAddress.fromJson(map);
  }

  /// PUT /clients/{clientId}/addresses/{addressId}
  /// Actualiza una dirección específica
  Future<ClientAddress> updateAddress(
    int clientId,
    int addressId,
    Map<String, dynamic> payload,
  ) async {
    final res = await _dio.put(
      '/clients/$clientId/addresses/$addressId',
      data: payload,
    );

    final body = res.data;
    late final Map<String, dynamic> map;

    if (body is Map && body['data'] is Map) {
      map = (body['data'] as Map).map((k, v) => MapEntry(k.toString(), v));
    } else if (body is Map) {
      map = body.map((k, v) => MapEntry(k.toString(), v));
    } else {
      throw Exception('Respuesta inesperada al actualizar dirección');
    }
    return ClientAddress.fromJson(map);
  }

  /// DELETE /clients/{clientId}/addresses/{addressId}
  /// Elimina una dirección
  Future<void> deleteAddress(int clientId, int addressId) async {
    try {
      await _dio.delete('/clients/$clientId/addresses/$addressId');
    } catch (e) {
      debugPrint('Error en deleteAddress: $e');
      rethrow;
    }
  }
}
