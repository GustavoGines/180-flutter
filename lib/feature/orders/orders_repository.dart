import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../../core/network/dio_client.dart';
import '../../core/models/order.dart';
import '../../core/config.dart';
import '../auth/auth_state.dart';

final ordersRepoProvider = Provider<OrdersRepository>(
  (ref) => OrdersRepository(ref),
);

class OrdersRepository {
  final Dio _dio = DioClient().dio;
  final Ref _ref;

  OrdersRepository(this._ref);

  Future<String> _compressImage(XFile originalFile) async {
    final tempDir = await getTemporaryDirectory();
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${originalFile.name.split('/').last}.jpg';
    final tempPath = '${tempDir.path}/$fileName';

    try {
      final compressedBytes = await FlutterImageCompress.compressWithFile(
        originalFile.path,
        minWidth: 1200,
        minHeight: 1200,
        quality: 80,
        format: CompressFormat.jpeg,
      );

      if (compressedBytes != null) {
        final tempFile = File(tempPath);
        await tempFile.writeAsBytes(compressedBytes);
        debugPrint('Imagen comprimida en: $tempPath');
        return tempPath;
      } else {
        debugPrint(
          'Falló la compresión, usando original: ${originalFile.path}',
        );
        return originalFile.path;
      }
    } catch (e) {
      debugPrint("Error en _compressImage: $e");
      return originalFile.path;
    }
  }

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

    final data = res.data;
    if (data is Map<String, dynamic> && data.containsKey('data')) {
      final List<dynamic> orderList = data['data'];
      return orderList
          .map((j) => Order.fromJson(j as Map<String, dynamic>))
          .toList();
    }

    if (data is List<dynamic>) {
      return data
          .map((j) => Order.fromJson(j as Map<String, dynamic>))
          .toList();
    }

    return [];
  }

  Future<Order> getOrderById(int id) async {
    final res = await _dio.get('/orders/$id');
    return Order.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> deleteOrder(int id) async {
    await _dio.delete('/orders/$id');
  }

  Future<Order?> updateStatus(int orderId, String status) async {
    try {
      final response = await _dio.patch(
        '/orders/$orderId/status',
        data: {'status': status},
      );
      return Order.fromJson(response.data);
    } catch (e) {
      if (kDebugMode) {
        print('Error al actualizar estado: $e');
      }
      return null;
    }
  }

  Future<Order?> markAsPaid(int orderId) async {
    try {
      final response = await _dio.patch('/orders/$orderId/mark-paid');
      return Order.fromJson(response.data);
    } on DioException catch (e) {
      if (kDebugMode) {
        print('Error al marcar como pagado: $e');
      }
      rethrow;
    }
  }

  Future<Order> createOrderWithFiles(
    Map<String, dynamic> payload,
    Map<String, XFile> files,
  ) async {
    final token = await _ref.read(authTokenProvider.future);
    final uri = Uri.parse('$kApiBase/orders');
    final request = http.MultipartRequest('POST', uri);

    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'application/json';
    request.fields['order_payload'] = jsonEncode(payload);

    final List<String> tempPaths = [];

    try {
      for (var entry in files.entries) {
        final placeholderId = entry.key;
        final file = entry.value;

        final String pathToSend = await _compressImage(file);
        if (pathToSend != file.path) {
          tempPaths.add(pathToSend);
        }

        request.files.add(
          await http.MultipartFile.fromPath(
            'files[$placeholderId]',
            pathToSend,
            filename: file.name,
          ),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        return Order.fromJson(jsonDecode(response.body));
      } else {
        if (kDebugMode) {
          print('Error createOrderWithFiles: ${response.body}');
        }
        throw Exception(
          'Error al crear pedido: ${response.statusCode} ${response.body}',
        );
      }
    } finally {
      for (var path in tempPaths) {
        try {
          File(path).delete();
        } catch (e) {
          debugPrint('Error borrando archivo temporal: $e');
        }
      }
    }
  }

  Future<Order> updateOrderWithFiles(
    int orderId,
    Map<String, dynamic> payload,
    Map<String, XFile> files,
  ) async {
    final token = await _ref.read(authTokenProvider.future);
    final uri = Uri.parse('$kApiBase/orders/$orderId');
    final request = http.MultipartRequest('POST', uri);
    request.fields['_method'] = 'PUT';

    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'application/json';
    request.fields['order_payload'] = jsonEncode(payload);

    final List<String> tempPaths = [];

    try {
      for (var entry in files.entries) {
        final placeholderId = entry.key;
        final file = entry.value;

        final String pathToSend = await _compressImage(file);
        if (pathToSend != file.path) {
          tempPaths.add(pathToSend);
        }

        request.files.add(
          await http.MultipartFile.fromPath(
            'files[$placeholderId]',
            pathToSend,
            filename: file.name,
          ),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return Order.fromJson(jsonDecode(response.body));
      } else {
        if (kDebugMode) {
          print('Error updateOrderWithFiles: ${response.body}');
        }
        throw Exception(
          'Error al actualizar pedido: ${response.statusCode} ${response.body}',
        );
      }
    } finally {
      for (var path in tempPaths) {
        try {
          File(path).delete();
        } catch (e) {
          debugPrint('Error borrando archivo temporal: $e');
        }
      }
    }
  }
}
