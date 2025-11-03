part of '../home_page.dart';

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon, // 👈 AÑADIDO: Icono personalizado
    required this.color, // 👈 AÑADIDO: Color personalizado
    this.isCurrency = true, // 👈 AÑADIDO: Flag de formato
  });

  final String title;
  final double value;
  final IconData icon;
  final Color color; // Este es _tertiaryMint (siempre claro)
  final bool isCurrency;

  @override
  Widget build(BuildContext context) {
    final fmtCurrency = NumberFormat(r"'$' #,##0.00", 'es_AR');
    final fmtInt = NumberFormat("#,##0", 'es_AR'); // Formato para enteros

    final theme = Theme.of(context); // 1. Obtenemos el tema
    final cs = theme.colorScheme;
    final textTheme = theme.textTheme;

    // --- 👇 AQUÍ ESTÁ LA NUEVA LÓGICA 👇 ---

    // 2. Detectamos si estamos en Modo Claro
    final bool isLightMode = theme.brightness == Brightness.light;

    // 3. Decidimos el color del contenido (número e ícono)
    final Color contentColor;

    if (isLightMode) {
      // MODO CLARO:
      // El fondo (surfaceContainerHighest) es gris claro.
      // Forzamos el texto a ser 'cs.primary' (que es tu _darkBrown).
      contentColor = cs.primary;
    } else {
      // MODO OSCURO:
      // El fondo (surfaceContainerHighest) es gris oscuro.
      // Usamos el color menta 'color' (que es _tertiaryMint, claro).
      contentColor = color;
    }
    // --- 👆 FIN DE LA LÓGICA 👆 ---

    // Formateo dinámico
    String show;
    if (isCurrency) {
      final prefix = (value >= 0) ? '+' : '';
      show = prefix + fmtCurrency.format(value);
    } else {
      show = fmtInt.format(value); // Mostrar como entero
    }

    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest, // Fondo (Gris claro / Gris oscuro)
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // --- 👇 CORRECCIÓN APLICADA 👇 ---
            Icon(icon, color: contentColor, size: 28), // Usa el color dinámico
            // --- 👆 FIN CORRECCIÓN 👆 ---
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.labelLarge?.copyWith(
                      color: cs.onSurfaceVariant, // El título ya estaba bien
                    ),
                  ),
                  const SizedBox(height: 2),
                  // ✅ SOLUCIÓN: Envuelve el Text en un FittedBox
                  FittedBox(
                    fit: BoxFit.scaleDown, // Encoge el texto si no entra
                    alignment: Alignment.centerLeft, // Lo alinea a la izquierda

                    child: Text(
                      show,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        // --- 👇 CORRECCIÓN APLICADA 👇 ---
                        color: contentColor, // Usa el color dinámico
                        // --- 👆 FIN CORRECCIÓN 👆 ---
                        letterSpacing: 0.1,
                      ),
                      // Buenas prácticas para asegurar una línea:
                      maxLines: 1,
                      softWrap: false,
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
