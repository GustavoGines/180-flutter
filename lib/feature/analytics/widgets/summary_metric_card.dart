// lib/feature/analytics/widgets/summary_metric_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Tarjeta de métrica grande para el Dashboard de Analytics.
///
/// Muestra un valor principal (ingresos, pedidos, etc.) con un subtítulo
/// opcional y un indicador de color semántico.
class SummaryMetricCard extends StatelessWidget {
  const SummaryMetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
    this.isCurrency = true,
    this.isFullWidth = false,
    this.isPrivacy = false,
    this.badgeWidget,
  });

  final String title;
  final double value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final bool isCurrency;
  final bool isFullWidth;
  final bool isPrivacy;
  final Widget? badgeWidget;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final contentColor = isLight ? cs.primary : color;

    final fmtCurrency = NumberFormat(r"'$' #,##0", 'es_AR');
    final fmtInt = NumberFormat('#,##0', 'es_AR');




    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.labelMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (badgeWidget != null) ...[
                        const SizedBox(width: 4),
                        badgeWidget!,
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: value),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      builder: (context, animated, _) {
                        final String shown;
                        if (isPrivacy) {
                          shown = '***';
                        } else {
                          shown = isCurrency
                              ? fmtCurrency.format(animated)
                              : fmtInt.format(animated.round());
                        }
                        return Text(
                          shown,
                          style: tt.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: contentColor,
                            letterSpacing: -0.5,
                          ),
                        );
                      },
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!isFullWidth)
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: cs.onSurfaceVariant.withValues(alpha: 0.4),
              ),
          ],
        ),
      ),
    );
  }
}
