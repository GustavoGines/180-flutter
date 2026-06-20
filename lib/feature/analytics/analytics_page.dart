// lib/feature/analytics/analytics_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:riverpod/riverpod.dart' as rp;

import '../../core/enums/order_status.dart';
import '../../core/models/order.dart';
import '../orders/orders_repository.dart';
import 'analytics_model.dart';
import 'widgets/daily_trend_area_chart.dart';
import 'widgets/product_breakdown_list.dart';
import 'widgets/products_donut_chart.dart';
import 'widgets/products_horizontal_bar_chart.dart';
import 'widgets/summary_metric_card.dart';

// ─────────────────────────── Providers ───────────────────────────

enum PaymentStatusFilter { all, paid, pending }

// Helper record to manage period calculations
typedef _PeriodCalc = ({DateTime start, DateTime end, DateTime prevStart, DateTime prevEnd, bool isSingleMonth, DateTime targetMonth, int rangeMonths});

_PeriodCalc _parsePeriod(String key) {
  final now = DateTime.now();
  if (key == '1M') {
    return (
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month + 1, 0),
      prevStart: DateTime(now.year, now.month - 1, 1),
      prevEnd: DateTime(now.year, now.month, 0),
      isSingleMonth: true,
      targetMonth: now,
      rangeMonths: 1,
    );
  } else if (key == '3M') {
    return (
      start: DateTime(now.year, now.month - 2, 1),
      end: DateTime(now.year, now.month + 1, 0),
      prevStart: DateTime(now.year, now.month - 5, 1),
      prevEnd: DateTime(now.year, now.month - 2, 0),
      isSingleMonth: false,
      targetMonth: now,
      rangeMonths: 3,
    );
  } else if (key == '6M') {
    return (
      start: DateTime(now.year, now.month - 5, 1),
      end: DateTime(now.year, now.month + 1, 0),
      prevStart: DateTime(now.year, now.month - 11, 1),
      prevEnd: DateTime(now.year, now.month - 5, 0),
      isSingleMonth: false,
      targetMonth: now,
      rangeMonths: 6,
    );
  } else if (key == '12M') {
    return (
      start: DateTime(now.year, now.month - 11, 1),
      end: DateTime(now.year, now.month + 1, 0),
      prevStart: DateTime(now.year, now.month - 23, 1),
      prevEnd: DateTime(now.year, now.month - 11, 0),
      isSingleMonth: false,
      targetMonth: now,
      rangeMonths: 12,
    );
  } else {
    // Specific month
    final parts = key.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final target = DateTime(year, month, 1);
    return (
      start: target,
      end: DateTime(year, month + 1, 0),
      prevStart: DateTime(year, month - 1, 1),
      prevEnd: DateTime(year, month, 0),
      isSingleMonth: true,
      targetMonth: target,
      rangeMonths: 1,
    );
  }
}

extension _PaymentFilterExt on PaymentStatusFilter {
  String get label => switch (this) {
        PaymentStatusFilter.all => 'Todos',
        PaymentStatusFilter.paid => 'Pagados',
        PaymentStatusFilter.pending => 'Pendientes',
      };
}

final _selectedPeriodProvider = rp.StateProvider<String>((ref) => '1M');
final _statusFilterProvider = rp.StateProvider<PaymentStatusFilter>((ref) => PaymentStatusFilter.all);
final _privacyModeProvider = rp.StateProvider<bool>((ref) => false);

/// Pedidos crudos desde el backend (traemos el DOBLE de tiempo para la comparativa)
final _periodOrdersProvider = rp.FutureProvider.autoDispose<List<Order>>((ref) async {
  final period = ref.watch(_selectedPeriodProvider);
  final repo = ref.watch(ordersRepoProvider);
  final calc = _parsePeriod(period);
  return repo.getOrders(from: calc.prevStart, to: calc.end);
});

/// Pedidos filtrados en memoria por el estado de pago (Latencia cero)
final _filteredOrdersProvider = rp.Provider.autoDispose<List<Order>>((ref) {
  final ordersAsync = ref.watch(_periodOrdersProvider);
  final statusFilter = ref.watch(_statusFilterProvider);
  final period = ref.watch(_selectedPeriodProvider);
  final calc = _parsePeriod(period);

  return ordersAsync.when(
    data: (orders) {
      return orders.where((o) {
        if (o.status == OrderStatus.canceled) return false;
        if (o.eventDate.isBefore(calc.start) || o.eventDate.isAfter(calc.end)) return false;
        switch (statusFilter) {
          case PaymentStatusFilter.all:
            return true;
          case PaymentStatusFilter.paid:
            return o.isPaid == true;
          case PaymentStatusFilter.pending:
            return o.isPaid == false;
        }
      }).toList();
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

/// Pedidos del período ANTERIOR (Latencia cero)
final _previousFilteredOrdersProvider = rp.Provider.autoDispose<List<Order>>((ref) {
  final ordersAsync = ref.watch(_periodOrdersProvider);
  final statusFilter = ref.watch(_statusFilterProvider);
  final period = ref.watch(_selectedPeriodProvider);
  final calc = _parsePeriod(period);

  return ordersAsync.when(
    data: (orders) {
      return orders.where((o) {
        if (o.status == OrderStatus.canceled) return false;
        if (o.eventDate.isBefore(calc.prevStart) || o.eventDate.isAfter(calc.prevEnd)) return false;
        switch (statusFilter) {
          case PaymentStatusFilter.all:
            return true;
          case PaymentStatusFilter.paid:
            return o.isPaid == true;
          case PaymentStatusFilter.pending:
            return o.isPaid == false;
        }
      }).toList();
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

/// Resumen global del filtro actual
final _localSummaryProvider = rp.Provider.autoDispose<({double total, int count, double previousTotal})>((ref) {
  final orders = ref.watch(_filteredOrdersProvider);
  final previousOrders = ref.watch(_previousFilteredOrdersProvider);
  
  double total = 0;
  for (final o in orders) {
    total += o.total ?? 0;
  }
  
  double prevTotal = 0;
  for (final o in previousOrders) {
    prevTotal += o.total ?? 0;
  }
  
  return (total: total, count: orders.length, previousTotal: prevTotal);
});

/// Agrupación de productos (Top 5 + Otros)
final _localTopProductsProvider = rp.Provider.autoDispose<List<TopProductItem>>((ref) {
  final orders = ref.watch(_filteredOrdersProvider);
  final Map<String, ({double qty, double revenue})> acc = {};

  for (final o in orders) {
    for (final item in o.items) {
      final prev = acc[item.name];
      final revenue = item.finalLinePrice;
      acc[item.name] = prev == null
          ? (qty: item.qty, revenue: revenue)
          : (qty: prev.qty + item.qty, revenue: prev.revenue + revenue);
    }
  }

  final sorted = acc.entries.toList()..sort((a, b) => b.value.revenue.compareTo(a.value.revenue));
  
  if (sorted.isEmpty) return [];

  final top5 = sorted.take(5).map(
    (e) => TopProductItem(name: e.key, totalQty: e.value.qty, totalRevenue: e.value.revenue),
  ).toList();

  if (sorted.length > 5) {
    final others = sorted.skip(5);
    double othersQty = 0;
    double othersRev = 0;
    for (var o in others) {
      othersQty += o.value.qty;
      othersRev += o.value.revenue;
    }
    top5.add(TopProductItem(name: 'Otros', totalQty: othersQty, totalRevenue: othersRev));
  }

  return top5;
});

/// Agrupación de productos por Volumen (Top 10 Cantidades)
final _localTopVolumeProvider = rp.Provider.autoDispose<List<TopProductItem>>((ref) {
  final orders = ref.watch(_filteredOrdersProvider);
  final Map<String, ({double qty, double revenue})> acc = {};

  for (final o in orders) {
    for (final item in o.items) {
      final prev = acc[item.name];
      final revenue = item.finalLinePrice;
      acc[item.name] = prev == null
          ? (qty: item.qty, revenue: revenue)
          : (qty: prev.qty + item.qty, revenue: prev.revenue + revenue);
    }
  }

  // Ordenar por QTY en lugar de Revenue
  final sorted = acc.entries.toList()..sort((a, b) => b.value.qty.compareTo(a.value.qty));
  
  if (sorted.isEmpty) return [];

  return sorted.take(10).map(
    (e) => TopProductItem(name: e.key, totalQty: e.value.qty, totalRevenue: e.value.revenue),
  ).toList();
});

/// Tendencia diaria (Agrupa por día)
final _dailyTrendProvider = rp.Provider.autoDispose<List<TrendPoint>>((ref) {
  final orders = ref.watch(_filteredOrdersProvider);
  final period = ref.watch(_selectedPeriodProvider);
  final calc = _parsePeriod(period);

  if (orders.isEmpty) return [];

  // Si es un solo mes, agrupamos por día. Si son varios, agrupamos por mes.
  if (calc.isSingleMonth) {
    final targetDate = calc.targetMonth;
    final daysInMonth = DateTime(targetDate.year, targetDate.month + 1, 0).day;
    final Map<int, double> dailyTotals = {for (var i = 1; i <= daysInMonth; i++) i: 0.0};

    for (final o in orders) {
      if (o.eventDate.year == targetDate.year && o.eventDate.month == targetDate.month) {
        dailyTotals[o.eventDate.day] = dailyTotals[o.eventDate.day]! + (o.total ?? 0);
      }
    }

    return dailyTotals.entries.map((e) {
      final date = DateTime(targetDate.year, targetDate.month, e.key);
      return TrendPoint(date: date, label: '${e.key} ${DateFormat('MMM', 'es_AR').format(date)}', value: e.value);
    }).toList();
  } else {
    // Para períodos más largos, agrupamos por mes
    final Map<String, double> monthlyTotals = {};
    for (int i = calc.rangeMonths - 1; i >= 0; i--) {
      final targetDate = DateTime(calc.targetMonth.year, calc.targetMonth.month - i, 1);
      final key = '${targetDate.year}-${targetDate.month}';
      monthlyTotals[key] = 0.0;
    }

    for (final o in orders) {
      final key = '${o.eventDate.year}-${o.eventDate.month}';
      if (monthlyTotals.containsKey(key)) {
        monthlyTotals[key] = monthlyTotals[key]! + (o.total ?? 0);
      }
    }

    return monthlyTotals.entries.map((e) {
      final parts = e.key.split('-');
      final date = DateTime(int.parse(parts[0]), int.parse(parts[1]));
      return TrendPoint(date: date, label: DateFormat('MMM yy', 'es_AR').format(date), value: e.value);
    }).toList();
  }
});

// ─────────────────────────── Page ────────────────────────────────

class AnalyticsPage extends ConsumerWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    
    final period = ref.watch(_selectedPeriodProvider);
    final statusFilter = ref.watch(_statusFilterProvider);
    final ordersAsync = ref.watch(_periodOrdersProvider);
    
    final summary = ref.watch(_localSummaryProvider);
    final topProducts = ref.watch(_localTopProductsProvider);
    final topVolume = ref.watch(_localTopVolumeProvider);
    final trendData = ref.watch(_dailyTrendProvider);
    
    final isLoading = ordersAsync.isLoading;

    final isPrivacy = ref.watch(_privacyModeProvider);

    final double avgTicketValue = summary.count > 0 ? summary.total / summary.count : 0;
    final String avgTicketSubtitle = summary.count > 0 
        ? 'Ticket Promedio: ${isPrivacy ? '***' : NumberFormat(r"'$'#,##0", 'es_AR').format(avgTicketValue)}' 
        : 'Sin ventas';

    // Cálculo del Badge de Crecimiento
    double growthPercent = 0.0;
    if (summary.previousTotal > 0) {
      growthPercent = ((summary.total - summary.previousTotal) / summary.previousTotal) * 100;
    } else if (summary.total > 0) {
      growthPercent = 100.0; // Si antes era 0 y ahora hay ventas
    }
    
    final bool hasGrowth = summary.previousTotal > 0 || summary.total > 0;
    final bool isPositiveGrowth = growthPercent >= 0;

    // Color dinámico según filtro
    final mainColor = switch (statusFilter) {
      PaymentStatusFilter.all => cs.primary,
      PaymentStatusFilter.paid => const Color(0xFF4CAF50), // Verde
      PaymentStatusFilter.pending => cs.error, // Rojo
    };

    final donutColors = [
      mainColor,
      mainColor.withValues(alpha: 0.8),
      mainColor.withValues(alpha: 0.6),
      mainColor.withValues(alpha: 0.4),
      mainColor.withValues(alpha: 0.2),
      cs.outlineVariant, // Otros
    ];

    return Scaffold(
      backgroundColor: cs.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            actions: [
              IconButton(
                icon: Icon(isPrivacy ? Icons.visibility_off : Icons.visibility),
                tooltip: 'Modo Privacidad',
                onPressed: () {
                  ref.read(_privacyModeProvider.notifier).state = !isPrivacy;
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              title: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Análisis', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Filtro de Estado (Pagados/Pendientes) ──
                SegmentedButton<PaymentStatusFilter>(
                  segments: PaymentStatusFilter.values.map((f) {
                    return ButtonSegment(value: f, label: Text(f.label));
                  }).toList(),
                  selected: {statusFilter},
                  showSelectedIcon: false,
                  onSelectionChanged: (set) => ref.read(_statusFilterProvider.notifier).state = set.first,
                  style: SegmentedButton.styleFrom(
                    backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                    selectedForegroundColor: cs.onPrimary,
                    selectedBackgroundColor: mainColor,
                  ),
                ),
                const SizedBox(height: 16),
                
                // ── Selector de Tiempo en Dropdown ──
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: period,
                      icon: const Icon(Icons.calendar_month),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem(value: '1M', child: Text('Últimos 30 días', style: TextStyle(fontWeight: FontWeight.bold))),
                        const DropdownMenuItem(value: '3M', child: Text('Últimos 3 Meses', style: TextStyle(fontWeight: FontWeight.bold))),
                        const DropdownMenuItem(value: '6M', child: Text('Últimos 6 Meses', style: TextStyle(fontWeight: FontWeight.bold))),
                        const DropdownMenuItem(value: '12M', child: Text('Último Año', style: TextStyle(fontWeight: FontWeight.bold))),
                        const DropdownMenuItem(value: '', enabled: false, child: Divider()),
                        ...List.generate(12, (i) {
                          final target = DateTime(DateTime.now().year, DateTime.now().month - i, 1);
                          final key = '${target.year}-${target.month}';
                          final label = toBeginningOfSentenceCase(DateFormat('MMMM yyyy', 'es_AR').format(target));
                          return DropdownMenuItem(value: key, child: Text(label));
                        }),
                      ],
                      onChanged: (val) {
                        if (val != null && val.isNotEmpty) {
                          ref.read(_selectedPeriodProvider.notifier).state = val;
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Tarjetas Resumen ──
                Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: SummaryMetricCard(
                        title: statusFilter == PaymentStatusFilter.all 
                            ? 'Total Facturado' 
                            : statusFilter == PaymentStatusFilter.paid 
                                ? 'Ingreso Real' 
                                : 'Deuda Pendiente',
                        value: summary.total,
                        subtitle: avgTicketSubtitle,
                        isPrivacy: isPrivacy,
                        badgeWidget: hasGrowth ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isPositiveGrowth ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isPositiveGrowth ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                color: isPositiveGrowth ? Colors.green : Colors.red,
                                size: 12,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${isPositiveGrowth ? '+' : ''}${growthPercent.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  color: isPositiveGrowth ? Colors.green : Colors.red,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ) : null,
                        icon: statusFilter == PaymentStatusFilter.pending ? Icons.warning_amber_rounded : Icons.account_balance_wallet_rounded,
                        color: mainColor,
                        isFullWidth: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: SummaryMetricCard(
                        title: 'Pedidos',
                        value: summary.count.toDouble(),
                        icon: Icons.shopping_bag_rounded,
                        color: cs.secondary,
                        isCurrency: false,
                        isFullWidth: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                  // ── Gráfico de Tendencia (Área) ──
                if (isLoading) const _ChartSkeleton(height: 220)
                else ...[
                  Card(
                    elevation: 0,
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3))),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 24, 16),
                      child: SizedBox(
                        height: 240, // Más alto para que se vea moderno y profesional
                        child: DailyTrendAreaChart(points: trendData, lineColor: mainColor),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 32),

                // ── Desglose de Productos (Donut + Lista) ──
                Text(
                  'Desglose por Producto',
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                
                if (isLoading) const _ChartSkeleton(height: 240)
                else if (topProducts.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Sin ventas para los filtros seleccionados.', style: TextStyle(color: cs.onSurfaceVariant)),
                    ),
                  )
                else ...[
                  // Donut Chart
                  ProductsDonutChart(
                    items: topProducts,
                    totalRevenue: summary.total,
                    colors: donutColors,
                  ),
                  const SizedBox(height: 24),
                  
                  // Lista Detallada ($)
                  ProductBreakdownList(
                    items: topProducts,
                    totalRevenue: summary.total,
                    colors: donutColors,
                  ),

                  const SizedBox(height: 32),
                  const Divider(height: 1),
                  const SizedBox(height: 24),

                  // ── Ranking de Volumen de Producción ──
                  Text(
                    'Volumen de Producción (Unidades)',
                    style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ProductsHorizontalBarChart(
                    items: topVolume,
                    mainColor: mainColor,
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}


class _ChartSkeleton extends StatelessWidget {
  const _ChartSkeleton({required this.height});
  final double height;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: height,
      child: Center(child: CircularProgressIndicator(strokeWidth: 2.5, color: cs.primary)),
    );
  }
}
