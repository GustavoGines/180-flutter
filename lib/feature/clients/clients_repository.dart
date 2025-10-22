import 'package:dio/dio.dart';
import '../../core/network/dio_client.dart';
import '../../core/models/client.dart';

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
        .map<Map<String, dynamic>>((m) => m.map((k, v) => MapEntry(k.toString(), v)))
        .map(Client.fromJson)
        .toList();
  }

  /// POST /clients
  Future<Client> createClient(Map<String, dynamic> payload) async {
    final res = await _dio.post('/clients', data: payload);
    final body = res.data;
  
    // Normalizamos a Map<String, dynamic>
    late final Map<String, dynamic> map;
    if (body is Map<String, dynamic>) {
      map = body;
    } else if (body is Map) {
      map = body.map((k, v) => MapEntry(k.toString(), v));
    } else {
      throw Exception('Respuesta inesperada al crear cliente: ${body.runtimeType}');
    }
  
    return Client.fromJson(map);
  }

  
}
