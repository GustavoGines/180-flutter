// lib/feature/analytics/widgets/product_breakdown_list.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../analytics_model.dart';

class ProductBreakdownList extends StatelessWidget {
  const ProductBreakdownList({
    super.key,
    required this.items,
    required this.totalRevenue,
    required this.colors,
    this.isPrivacy = false,
  });

  final List<TopProductItem> items;
  final double totalRevenue;
  final List<Color> colors;
  final bool isPrivacy;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty || totalRevenue == 0) return const SizedBox.shrink();

    return Column(
      children: List.generate(items.length, (i) {
        final item = items[i];
        final color = colors[i % colors.length];
        final percentage = (item.totalRevenue / totalRevenue);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _BreakdownItem(
            name: item.name,
            amount: item.totalRevenue,
            percentage: percentage,
            color: color,
            isPrivacy: isPrivacy,
          ),
        );
      }),
    );
  }
}

class _BreakdownItem extends StatelessWidget {
  const _BreakdownItem({
    required this.name,
    required this.amount,
    required this.percentage,
    required this.color,
    required this.isPrivacy,
  });

  final String name;
  final double amount;
  final double percentage;
  final Color color;
  final bool isPrivacy;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final fmtCurrency = NumberFormat(r"'$'#,##0", 'es_AR');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          // Avatar Pastel
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'P',
              style: tt.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Nombre del producto
          Expanded(
            child: Text(
              name,
              style: tt.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          // Monto y Porcentaje
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                isPrivacy ? '***' : fmtCurrency.format(amount),
                style: tt.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                '${(percentage * 100).toStringAsFixed(1)}%',
                style: tt.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
