import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../core/network/dio_client.dart';
import '../../core/models/order.dart';

final ordersRepoProvider = Provider<OrdersRepository>(
  (ref) => OrdersRepository(),
);

class OrdersRepository {
  final Dio _dio = DioClient().dio;

  Future<List<Order>> getOrders({
    required DateTime from,
    required DateTime to,
  }) async {
    final formatter = DateFormat('yyyy-MM-dd');
    final fromStr = formatter.format(from);
    final toStr = formatter.format(to);

    final res = await _dio.get(
      '/orders',
      queryParameters: {'from': fromStr, 'to': toStr},
    );

    // --- LÓGICA SIMPLIFICADA PARA PAGINACIÓN ---
    final data = res.data;
    if (data is Map<String, dynamic> && data.containsKey('data')) {
      final List<dynamic> orderList = data['data'];
      return orderList
          .map((j) => Order.fromJson(j as Map<String, dynamic>))
          .toList();
    }

    // Fallback si la respuesta no es paginada (aunque no debería pasar)
    if (data is List<dynamic>) {
      return data
          .map((j) => Order.fromJson(j as Map<String, dynamic>))
          .toList();
    }

    return []; // Devuelve una lista vacía si el formato es inesperado
  }

  Future<Order> getOrderById(int id) async {
    final res = await _dio.get('/orders/$id');
    return Order.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Order> createOrder(Map<String, dynamic> payload) async {
    final res = await _dio.post('/orders', data: payload);
    return Order.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Order> updateOrder(int id, Map<String, dynamic> payload) async {
    final res = await _dio.put('/orders/$id', data: payload);
    return Order.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> deleteOrder(int id) async {
    await _dio.delete('/orders/$id');
  }

  Future<String?> uploadImage(XFile imageFile) async {
    try {
      final formData = FormData.fromMap({
        'photo': await MultipartFile.fromFile(
          imageFile.path,
          filename: imageFile.name,
        ),
      });
      final response = await _dio.post('/orders/upload-photo', data: formData);
      return response.data['url'] as String?;
    } catch (e) {
      print('Error al subir la imagen: $e');
      return null;
    }
  }

  Future<Order?> updateStatus(int orderId, String status) async {
    try {
      final response = await _dio.patch(
        '/orders/$orderId/status',
        data: {'status': status},
      );
      return Order.fromJson(response.data);
    } catch (e) {
      print('Error al actualizar estado: $e');
      return null;
    }
  }

  Future<Order?> markAsPaid(int orderId) async {
    try {
      final response = await _dio.patch(
        '/orders/$orderId/status',
        data: {'is_fully_paid': true},
      );
      return Order.fromJson(response.data);
    } catch (e) {
      print('Error al marcar como pagado: $e');
      return null;
    }
  }
}
