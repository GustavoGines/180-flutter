import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/dio_client.dart';
import '../../core/models/catalog.dart';

// Provider global del catálogo
// Cacheamos la respuesta para no hacer requests innecesarios (FutureProvider)
final catalogProvider = FutureProvider<CatalogResponse>((ref) async {
  return ref.watch(catalogRepoProvider).getCatalog();
});

final catalogRepoProvider = Provider<CatalogRepository>(
  (ref) => CatalogRepository(),
);

class CatalogRepository {
  final Dio _dio = DioClient().dio;

  Future<CatalogResponse> getCatalog() async {
    try {
      final res = await _dio.get('/catalog');
      // res.data debería ser Map<String, dynamic>
      // La estructura real es {meta: ..., data: {...}}
      return CatalogResponse.fromJson(res.data);
    } catch (e) {
      throw Exception('Error al obtener el catálogo: $e');
    }
  }

  // --- ADMIN METHODS ---

  // Products
  Future<void> createProduct(Map<String, dynamic> data) async {
    try {
      await _dio.post('/admin/products', data: data);
    } catch (e) {
      throw Exception('Error creando producto: $e');
    }
  }

  Future<void> updateProduct(int id, Map<String, dynamic> data) async {
    try {
      await _dio.put('/admin/products/$id', data: data);
    } catch (e) {
      throw Exception('Error actualizando producto: $e');
    }
  }

  Future<void> deleteProduct(int id) async {
    try {
      await _dio.delete('/admin/products/$id');
    } catch (e) {
      throw Exception('Error eliminando producto: $e');
    }
  }

  // Fillings
  Future<void> createFilling(Map<String, dynamic> data) async {
    try {
      await _dio.post('/admin/fillings', data: data);
    } catch (e) {
      throw Exception('Error creando relleno: $e');
    }
  }

  Future<void> updateFilling(int id, Map<String, dynamic> data) async {
    try {
      await _dio.put('/admin/fillings/$id', data: data);
    } catch (e) {
      throw Exception('Error actualizando relleno: $e');
    }
  }

  Future<void> deleteFilling(int id) async {
    try {
      await _dio.delete('/admin/fillings/$id');
    } catch (e) {
      throw Exception('Error eliminando relleno: $e');
    }
  }

  // Extras
  Future<void> createExtra(Map<String, dynamic> data) async {
    try {
      await _dio.post('/admin/extras', data: data);
    } catch (e) {
      throw Exception('Error creando extra: $e');
    }
  }

  Future<void> updateExtra(int id, Map<String, dynamic> data) async {
    try {
      await _dio.put('/admin/extras/$id', data: data);
    } catch (e) {
      throw Exception('Error actualizando extra: $e');
    }
  }

  Future<void> deleteExtra(int id) async {
    try {
      await _dio.delete('/admin/extras/$id');
    } catch (e) {
      throw Exception('Error eliminando extra: $e');
    }
  }
}
