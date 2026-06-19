// lib/feature/analytics/widgets/products_donut_chart.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../analytics_model.dart';

class ProductsDonutChart extends StatefulWidget {
  const ProductsDonutChart({
    super.key,
    required this.items,
    required this.totalRevenue,
    required this.colors,
  });

  final List<TopProductItem> items;
  final double totalRevenue;
  final List<Color> colors;

  @override
  State<ProductsDonutChart> createState() => _ProductsDonutChartState();
}

class _ProductsDonutChartState extends State<ProductsDonutChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final fmtCurrency = NumberFormat(r"'$'#,##0", 'es_AR');

    if (widget.items.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Centro del Donut (Texto Total)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Total',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              Text(
                fmtCurrency.format(widget.totalRevenue),
                style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          // Gráfico Pie (Donut)
          PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        pieTouchResponse == null ||
                        pieTouchResponse.touchedSection == null) {
                      _touchedIndex = -1;
                      return;
                    }
                    _touchedIndex =
                        pieTouchResponse.touchedSection!.touchedSectionIndex;
                  });
                },
              ),
              borderData: FlBorderData(show: false),
              sectionsSpace: 4,
              centerSpaceRadius: 70, // Tamaño del hueco
              sections: List.generate(widget.items.length, (i) {
                final isTouched = i == _touchedIndex;
                final radius = isTouched ? 35.0 : 25.0;
                final item = widget.items[i];
                final percentage =
                    (item.totalRevenue / widget.totalRevenue) * 100;
                final color = widget.colors[i % widget.colors.length];

                return PieChartSectionData(
                  color: color,
                  value: item.totalRevenue,
                  title: '${percentage.toStringAsFixed(1)}%',
                  radius: radius,
                  titleStyle: TextStyle(
                    fontSize: isTouched ? 12.0 : 10.0,
                    fontWeight: FontWeight.bold,
                    color: cs.onInverseSurface,
                  ),
                  badgeWidget: isTouched
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: cs.inverseSurface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            item.name,
                            style: TextStyle(
                              color: cs.onInverseSurface,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : null,
                  badgePositionPercentageOffset: 1.2,
                );
              }),
            ),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
          ),
        ],
      ),
    );
  }
}
