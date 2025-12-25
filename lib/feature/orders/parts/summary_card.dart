part of '../home_page.dart';

class _SummaryCard extends ConsumerWidget {
  const _SummaryCard({
    required this.title,
    required this.valueProvider,
    required this.icon,
    required this.color,
    // 👇 NUEVO: Provider opcional para ingreso pendiente
    this.pendingValueProvider,
  });

  final String title;
  final ProviderBase<num> valueProvider;
  final ProviderBase<num>?
  pendingValueProvider; // 👈 NUEVO: Provider para el valor gris
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmtCurrency = NumberFormat(r"'$' #,##0.00", 'es_AR');
    final fmtInt = NumberFormat("#,##0", 'es_AR');

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final textTheme = theme.textTheme;

    // --- Lógica de color ---
    final bool isLightMode = theme.brightness == Brightness.light;
    final Color contentColor;
    if (isLightMode) {
      contentColor = cs.primary;
    } else {
      contentColor = color;
    }
    // --- Fin lógica de color ---

    // 1. Determinamos si es moneda basado en el provider
    final bool isCurrency = valueProvider == monthlyIncomeProvider;

    // 2. Obtenemos los VALORES
    final num targetValue = ref.watch(valueProvider);
    // 👇 NUEVO: Leer valor pendiente
    final num pendingValue = pendingValueProvider != null
        ? ref.watch(pendingValueProvider!)
        : 0;

    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: contentColor, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.labelLarge?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),

                  // 3. ENVOLVEMOS EL NÚMERO CON LA ANIMACIÓN
                  TweenAnimationBuilder<double>(
                    tween: Tween(end: targetValue.toDouble()),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    builder: (context, animatedValue, child) {
                      String show;
                      if (isCurrency) {
                        final prefix = (animatedValue >= 0) ? '+' : '';
                        show = prefix + fmtCurrency.format(animatedValue);
                      } else {
                        show = fmtInt.format(animatedValue.round());
                      }

                      return FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          show,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: contentColor,
                            letterSpacing: 0.1,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                          maxLines: 1,
                          softWrap: false,
                        ),
                      );
                    },
                  ),

                  // 👇 NUEVO: Mostrar pendiente si existe y es > 0
                  if (pendingValue > 0 && isCurrency)
                    Padding(
                      padding: const EdgeInsets.only(top: 2.0),
                      child: Text(
                        'Pendiente: ${fmtCurrency.format(pendingValue)}',
                        style: textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant.withOpacity(0.7),
                          fontSize: 10,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
