// lib/feature/analytics/analytics_model.dart

/// Resumen financiero de un mes específico.
class AnalyticsSummary {
  /// Total de pedidos entregados y pagados en el período.
  final double ingresoRealizado;

  /// Total de pedidos activos (pending/confirmed/ready/delivered) sin cobrar.
  final double ingresoPendiente;

  /// Cantidad de pedidos no cancelados en el período.
  final int totalPedidos;

  /// Año del período consultado.
  final int year;

  /// Mes del período consultado (1–12).
  final int month;

  const AnalyticsSummary({
    required this.ingresoRealizado,
    required this.ingresoPendiente,
    required this.totalPedidos,
    required this.year,
    required this.month,
  });

  factory AnalyticsSummary.fromJson(Map<String, dynamic> json) {
    return AnalyticsSummary(
      ingresoRealizado:
          double.tryParse(json['ingreso_realizado']?.toString() ?? '0') ?? 0.0,
      ingresoPendiente:
          double.tryParse(json['ingreso_pendiente']?.toString() ?? '0') ?? 0.0,
      totalPedidos:
          int.tryParse(json['total_pedidos']?.toString() ?? '0') ?? 0,
      year: int.tryParse(json['year']?.toString() ?? '0') ?? 0,
      month: int.tryParse(json['month']?.toString() ?? '0') ?? 0,
    );
  }

  /// Suma de ingresos realizados + pendientes para mostrar el potencial total.
  double get ingresoTotal => ingresoRealizado + ingresoPendiente;
}

/// Un ítem en el ranking de productos más vendidos.
class TopProductItem {
  /// Nombre del producto (ej. "Torta de Chocolate").
  final String name;

  /// Cantidad total vendida en el período.
  final double totalQty;

  /// Revenue total generado por este producto.
  final double totalRevenue;

  const TopProductItem({
    required this.name,
    required this.totalQty,
    required this.totalRevenue,
  });

  factory TopProductItem.fromJson(Map<String, dynamic> json) {
    return TopProductItem(
      name: json['name']?.toString() ?? 'Desconocido',
      totalQty:
          double.tryParse(json['total_qty']?.toString() ?? '0') ?? 0.0,
      totalRevenue:
          double.tryParse(json['revenue']?.toString() ?? '0') ?? 0.0,
    );
  }
}

class TrendPoint {
  TrendPoint({
    required this.date,
    required this.label,
    required this.value,
  });

  final DateTime date;
  final String label;
  final double value;
}
