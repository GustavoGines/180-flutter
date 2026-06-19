// lib/feature/analytics/analytics_repository.dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_client.dart';
import 'analytics_model.dart';

final analyticsRepoProvider = Provider<AnalyticsRepository>(
  (ref) => AnalyticsRepository(),
);

class AnalyticsRepository {
  final Dio _dio = DioClient().dio;

  /// Trae el resumen financiero para un mes y año específicos.
  /// El backend aplica Cache::remember con TTL dinámico (5 min si es mes
  /// actual, 24 h si es un mes pasado).
  Future<AnalyticsSummary> getSummary({
    required int year,
    required int month,
  }) async {
    final res = await _dio.get(
      '/analytics/summary',
      queryParameters: {'year': year, 'month': month},
    );
    final data = _extractData(res.data);
    return AnalyticsSummary.fromJson(data);
  }

  /// Trae el Top 5 de productos más vendidos en el rango de fechas indicado.
  Future<List<TopProductItem>> getTopProducts({
    required String from,
    required String to,
  }) async {
    final res = await _dio.get(
      '/analytics/top-products',
      queryParameters: {'from': from, 'to': to},
    );
    final data = _extractData(res.data);
    final list = data['items'] as List<dynamic>? ?? [];
    return list
        .map((e) => TopProductItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Extrae la clave 'data' si el backend la envuelve con Laravel Resources.
  Map<String, dynamic> _extractData(dynamic raw) {
    if (raw is Map<String, dynamic> && raw.containsKey('data')) {
      return raw['data'] as Map<String, dynamic>;
    }
    if (raw is Map<String, dynamic>) return raw;
    return {};
  }
}
