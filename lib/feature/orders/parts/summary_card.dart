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
  final Color color;
  final bool isCurrency;

  @override
  Widget build(BuildContext context) {
    final fmtCurrency = NumberFormat(r"'$' #,##0.00", 'es_AR');
    final fmtInt = NumberFormat("#,##0", 'es_AR'); // Formato para enteros

    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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
      color: cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28), // Usa el icono y color pasados
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
                  // ✅ SOLUCIÓN: Envuelve el Text en un FittedBox
                  FittedBox(
                    fit: BoxFit.scaleDown, // Encoge el texto si no entra
                    alignment: Alignment.centerLeft, // Lo alinea a la izquierda

                    child: Text(
                      show,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color, // Usa el color pasado
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
