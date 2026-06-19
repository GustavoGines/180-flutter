// lib/feature/analytics/widgets/products_horizontal_bar_chart.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../analytics_model.dart';

/// Gráfico de Barras Horizontales minimalista (estilo Notion)
/// Muestra el volumen de producción (qty) de cada producto.
class ProductsHorizontalBarChart extends StatelessWidget {
  const ProductsHorizontalBarChart({
    super.key,
    required this.items,
    required this.mainColor,
  });

  final List<TopProductItem> items;
  final Color mainColor;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    // Encontrar el valor máximo para escalar las barras proporcionalmente
    final maxQty = items.map((e) => e.totalQty).reduce((a, b) => a > b ? a : b);
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(items.length, (index) {
        final item = items[index];
        final isFirst = index == 0;
        final percentage = maxQty > 0 ? (item.totalQty / maxQty) : 0.0;
        
        // Formato para números (ej. 24.5 o 24 si no tiene decimales reales)
        final qtyText = item.totalQty == item.totalQty.roundToDouble() 
            ? item.totalQty.toInt().toString() 
            : NumberFormat('#,##0.0', 'es_AR').format(item.totalQty);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Row(
            children: [
              // Etiqueta del producto (Truncada si es muy larga)
              Expanded(
                flex: 4,
                child: Text(
                  item.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isFirst ? FontWeight.w600 : FontWeight.normal,
                    color: isFirst ? cs.onSurface : cs.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              
              // Barra horizontal animada y etiqueta de cantidad
              Expanded(
                flex: 6,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Row(
                      children: [
                        // La barra
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: percentage),
                          duration: const Duration(milliseconds: 700),
                          curve: Curves.easeOutCubic,
                          builder: (context, val, child) {
                            return Container(
                              height: 12, // Altura delgada estilo Notion
                              width: val * (constraints.maxWidth - 40), // -40 para dejar espacio al número
                              decoration: BoxDecoration(
                                color: isFirst ? mainColor : mainColor.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        // Número final (qty)
                        Text(
                          qtyText,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
