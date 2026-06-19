// lib/feature/analytics/widgets/daily_trend_area_chart.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../analytics_model.dart';

/// Gráfico de área (tendencia) que dibuja una línea suave y rellena
/// el área inferior con un gradiente. Adaptable a diario o mensual.
class DailyTrendAreaChart extends StatefulWidget {
  const DailyTrendAreaChart({
    super.key,
    required this.points,
    required this.lineColor,
  });

  final List<TrendPoint> points;
  final Color lineColor;

  @override
  State<DailyTrendAreaChart> createState() => _DailyTrendAreaChartState();
}

class _DailyTrendAreaChartState extends State<DailyTrendAreaChart> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmtCurrency = NumberFormat(r"'$'#,##0", 'es_AR');

    if (widget.points.isEmpty) {
      return Center(
        child: Text(
          'Sin datos para el período.',
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
      );
    }

    final spots = widget.points
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.value))
        .toList();

    // Calculamos el Y máximo con un 20% de margen para respirar
    final maxVal = widget.points
        .map((p) => p.value)
        .reduce((a, b) => a > b ? a : b);
    final maxY = maxVal > 0 ? maxVal * 1.2 : 1000.0;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (widget.points.length - 1).toDouble(),
        minY: 0,
        maxY: maxY,
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          getTouchedSpotIndicator: (barData, spotIndexes) {
            return spotIndexes.map((index) {
              return TouchedSpotIndicatorData(
                FlLine(
                  color: widget.lineColor.withValues(alpha: 0.3),
                  strokeWidth: 2,
                  dashArray: [4, 4],
                ),
                FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) =>
                      FlDotCirclePainter(
                    radius: 6,
                    color: widget.lineColor,
                    strokeWidth: 2,
                    strokeColor: cs.surface,
                  ),
                ),
              );
            }).toList();
          },
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => cs.inverseSurface,
            tooltipRoundedRadius: 12,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final point = widget.points[spot.x.round()];
                return LineTooltipItem(
                  '${point.label}\n',
                  TextStyle(
                    color: cs.onInverseSurface.withValues(alpha: 0.7),
                    fontSize: 10,
                    fontWeight: FontWeight.normal,
                  ),
                  children: [
                    TextSpan(
                      text: fmtCurrency.format(point.value),
                      style: TextStyle(
                        color: widget.lineColor,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                );
              }).toList();
            },
          ),
          touchCallback: (event, response) {
            if (response?.lineBarSpots == null ||
                event is FlTapUpEvent ||
                event is FlLongPressEnd) {
              setState(() => _touchedIndex = null);
            } else {
              setState(() {
                _touchedIndex = response!.lineBarSpots!.first.x.round();
              });
            }
          },
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 4,
          getDrawingHorizontalLine: (value) => FlLine(
            color: cs.outlineVariant.withValues(alpha: 0.3),
            strokeWidth: 1,
            dashArray: [5, 5],
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false), // Escondemos Y para look limpio
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: widget.points.length > 15 ? 5 : 1, // Skip labels si hay muchos días
              getTitlesWidget: (value, meta) {
                final index = value.round();
                if (index < 0 || index >= widget.points.length) {
                  return const SizedBox.shrink();
                }
                
                final isTouched = _touchedIndex == index;

                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    widget.points[index].label,
                    style: TextStyle(
                      fontSize: isTouched ? 12 : 10,
                      color: isTouched ? widget.lineColor : cs.onSurfaceVariant,
                      fontWeight: isTouched ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            preventCurveOverShooting: true,
            curveSmoothness: 0.35,
            color: widget.lineColor,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  widget.lineColor.withValues(alpha: 0.4),
                  widget.lineColor.withValues(alpha: 0.01),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
    );
  }
}
