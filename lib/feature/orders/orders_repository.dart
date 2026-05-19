import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../../core/network/dio_client.dart';
import '../../core/models/order.dart';

final ordersRepoProvider = Provider<OrdersRepository>(
  (ref) => OrdersRepository(ref),
);

class OrdersRepository {
  final Dio _dio = DioClient().dio;

  OrdersRepository(Ref ref);

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
    // 1. Definir el tiempo mínimo de carga percibida (ej. 500 ms)
    const Duration minDuration = Duration(milliseconds: 500);
    final stopwatch = Stopwatch()..start();

    final formatter = DateFormat('yyyy-MM-dd');
    final fromStr = formatter.format(from);
    final toStr = formatter.format(to);

    final res = await _dio.get(
      '/orders',
      queryParameters: {'from': fromStr, 'to': toStr, 'per_page': 5000},
    );

    // 2. Procesar los datos
    final List<Order> orders;
    final data = res.data;
    if (data is Map<String, dynamic> && data.containsKey('data')) {
      final List<dynamic> orderList = data['data'];
      orders = orderList
          .map((j) => Order.fromJson(j as Map<String, dynamic>))
          .toList();
    } else if (data is List<dynamic>) {
      orders = data
          .map((j) => Order.fromJson(j as Map<String, dynamic>))
          .toList();
    } else {
      orders = [];
    }

    // 3. Esperar el tiempo restante para alcanzar la duración mínima
    final elapsed = stopwatch.elapsed;
    if (elapsed < minDuration) {
      final remaining = minDuration - elapsed;
      await Future.delayed(remaining);
      debugPrint(
        '⌛ Se agregó un retraso de ${remaining.inMilliseconds}ms para asegurar la duración mínima.',
      );
    }
    stopwatch.stop();

    return orders; // Devolver los datos después del retraso asegurado
  }

  // Helper para extraer 'data' si existe (Laravel Resources)
  Map<String, dynamic> _parseOrderData(dynamic data) {
    if (data is Map<String, dynamic> && data.containsKey('data')) {
      return data['data'] as Map<String, dynamic>;
    }
    return data as Map<String, dynamic>;
  }

  Future<Order> getOrderById(int id) async {
    final res = await _dio.get('/orders/$id');
    return Order.fromJson(_parseOrderData(res.data));
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
      return Order.fromJson(_parseOrderData(response.data));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error al actualizar estado: $e');
      }
      return null;
    }
  }

  Future<Order?> markAsPaid(int orderId) async {
    try {
      final response = await _dio.patch('/orders/$orderId/mark-paid');
      return Order.fromJson(_parseOrderData(response.data));
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint('Error al marcar como pagado: $e');
      }
      rethrow;
    }
  }

  Future<Order> markAsUnpaid(int orderId) async {
    try {
      final response = await _dio.patch('/orders/$orderId/mark-unpaid');
      return Order.fromJson(_parseOrderData(response.data));
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint('Error al desmarcar como pagado: $e');
      }
      rethrow;
    }
  }

  Future<Order> createOrderWithFiles(
    Map<String, dynamic> payload,
    Map<String, XFile> files,
  ) async {
    final Map<String, dynamic> formDataMap = {
      'order_payload': jsonEncode(payload),
    };

    final List<String> tempPaths = [];

    try {
      for (var entry in files.entries) {
        final placeholderId = entry.key;
        final file = entry.value;

        final String pathToSend = await _compressImage(file);
        if (pathToSend != file.path) {
          tempPaths.add(pathToSend);
        }

        formDataMap['files[$placeholderId]'] = await MultipartFile.fromFile(
          pathToSend,
          filename: file.name,
        );
      }

      final formData = FormData.fromMap(formDataMap);

      final response = await _dio.post(
        '/orders',
        data: formData,
      );

      return Order.fromJson(_parseOrderData(response.data));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error createOrderWithFiles: $e');
      }
      rethrow;
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
    final Map<String, dynamic> formDataMap = {
      '_method': 'PUT',
      'order_payload': jsonEncode(payload),
    };

    final List<String> tempPaths = [];

    try {
      for (var entry in files.entries) {
        final placeholderId = entry.key;
        final file = entry.value;

        final String pathToSend = await _compressImage(file);
        if (pathToSend != file.path) {
          tempPaths.add(pathToSend);
        }

        formDataMap['files[$placeholderId]'] = await MultipartFile.fromFile(
          pathToSend,
          filename: file.name,
        );
      }

      final formData = FormData.fromMap(formDataMap);

      final response = await _dio.post(
        '/orders/$orderId',
        data: formData,
      );

      return Order.fromJson(_parseOrderData(response.data));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error updateOrderWithFiles: $e');
      }
      rethrow;
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
