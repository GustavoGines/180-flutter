part of '../home_page.dart';

class _SummaryCard extends ConsumerWidget {
  // 👈 CAMBIO a ConsumerWidget
  const _SummaryCard({
    required this.title,
    required this.valueProvider, // 👈 CAMBIO
    required this.icon,
    required this.color,
  });

  final String title;
  final ProviderBase<num> valueProvider; // 👈 CAMBIO (acepta int o double)
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 👈 CAMBIO (añade ref)
    final fmtCurrency = NumberFormat(r"'$' #,##0.00", 'es_AR');
    final fmtInt = NumberFormat("#,##0", 'es_AR');

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final textTheme = theme.textTheme;

    // --- Lógica de color (sin cambios) ---
    final bool isLightMode = theme.brightness == Brightness.light;
    final Color contentColor;
    if (isLightMode) {
      contentColor = cs.primary;
    } else {
      contentColor = color;
    }
    // --- Fin lógica de color ---

    // --- 👇 AQUÍ ESTÁN LOS CAMBIOS IMPORTANTES 👇 ---

    // 1. Determinamos si es moneda basado en el provider
    final bool isCurrency = valueProvider == monthlyIncomeProvider;

    // 2. Obtenemos el VALOR OBJETIVO del provider
    final num targetValue = ref.watch(valueProvider);

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
                    // El Tween 'end' se actualiza automáticamente con 'targetValue'
                    // y el 'TweenAnimationBuilder' anima desde el valor anterior.
                    tween: Tween(end: targetValue.toDouble()),
                    duration: const Duration(
                      milliseconds: 600,
                    ), // Duración del conteo
                    curve: Curves.easeOutCubic, // Curva suave
                    // 'animatedValue' es el valor en cada fotograma de la animación
                    builder: (context, animatedValue, child) {
                      // 4. Formateamos el valor animado en cada fotograma
                      String show;
                      if (isCurrency) {
                        final prefix = (animatedValue >= 0) ? '+' : '';
                        show = prefix + fmtCurrency.format(animatedValue);
                      } else {
                        // Redondeamos el valor animado para los 'Pedidos'
                        show = fmtInt.format(animatedValue.round());
                      }

                      return FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          show, // Mostramos el valor animado
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: contentColor,
                            letterSpacing: 0.1,
                            // Añadimos esto para que los números no "salten" de ancho
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                          maxLines: 1,
                          softWrap: false,
                        ),
                      );
                    },
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
