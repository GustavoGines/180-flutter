part of '../home_page.dart';

// 👇 REFACTORIZADO: De 'SliverPersistentHeaderDelegate' a 'StatelessWidget'
class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.orders});
  final List<Order> orders;

  @override
  Widget build(BuildContext context) {
    final DateTime date = orders.first.eventDate;
    final int count = orders.length;

    String totalString = '';

    // (La lógica de cálculo de 'totalString' no cambia)
    if (count >= 2) {
      double dayTotal = 0;
      for (final order in orders) {
        final v = order.total ?? 0;
        if (v >= 0) {
          dayTotal += v;
        }
      }
      final fmt = NumberFormat(r"'$' #,##0.00", 'es_AR');
      totalString = fmt.format(dayTotal);
    }

    final surface = Theme.of(context).colorScheme.surface;
    final textTheme = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Container(
      height: 44,
      color: surface,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          const Icon(Icons.calendar_today, size: 16),
          const SizedBox(width: 8),

          // 1. Nombre del día
          Text(
            _prettyDayLabel(date),
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: .2,
            ),
          ),

          // 👇 --- INICIO DE CAMBIOS ---

          // 2. Muestra el total (si no está vacío) JUSTO AL LADO
          if (totalString.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(
                left: 8.0,
              ), // Espacio entre nombre y total
              child: Text(
                totalString,
                // 3. Estilo más chiquito
                style: textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant.withOpacity(0.8), // Color sutil
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),

          const Spacer(), // 4. Mueve el Spacer al final
          // --- FIN DE CAMBIOS ---
        ],
      ),
    );
  }
}

class _WeekSeparator extends StatelessWidget {
  const _WeekSeparator({
    required this.weekStart,
    required this.weekEnd,
    required this.total,
    required this.currentDisplayMonth, // 👈 NUEVO: Recibe el mes correcto
    this.muted = false,
  });
  final DateTime weekStart;
  final DateTime weekEnd;
  final double total;
  final DateTime currentDisplayMonth; // 👈 NUEVO
  final bool muted;

  @override
  Widget build(BuildContext context) {
    // 👇 --- LÓGICA SIMPLIFICADA USANDO currentDisplayMonth ---
    // 1. Usa SIEMPRE currentDisplayMonth para los límites y el nombre
    final monthShort = DateFormat(
      'MMM',
      'es_AR',
    ).format(currentDisplayMonth).toLowerCase();
    final firstDayOfMonth = DateTime(
      currentDisplayMonth.year,
      currentDisplayMonth.month,
      1,
    );
    final lastDayOfMonth = DateTime(
      currentDisplayMonth.year,
      currentDisplayMonth.month + 1,
      0,
    );

    // 2. Determina la fecha de inicio a mostrar:
    //    Es el día MÁS TARDÍO entre el inicio real de la semana (weekStart)
    //    y el primer día del mes que estamos mostrando (firstDayOfMonth).
    final DateTime displayStartDate = weekStart.isBefore(firstDayOfMonth)
        ? firstDayOfMonth
        : weekStart;

    // 3. Determina la fecha de fin a mostrar:
    //    Es el día MÁS TEMPRANO entre el fin real de la semana (weekEnd)
    //    y el último día del mes que estamos mostrando (lastDayOfMonth).
    final DateTime displayEndDate = weekEnd.isAfter(lastDayOfMonth)
        ? lastDayOfMonth
        : weekEnd;

    // 4. Formatea el rango usando los días recortados y el nombre del mes que estamos mostrando
    final startDayStr = displayStartDate.day.toString().padLeft(2);
    final endDayStr = displayEndDate.day.toString().padLeft(2);
    final range = '$monthShort $startDayStr - $endDayStr';
    // --- FIN LÓGICA SIMPLIFICADA ---

    final cs = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: muted
          ? cs.outline.withOpacity(0.6)
          : cs.onSurface.withOpacity(0.7),
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final verticalPadding = muted ? 4.0 : 16.0;

    // --- Lógica de Total (sin cambios) ---
    final String txt;
    final Color color;
    if (!muted) {
      final fmt = NumberFormat(r"'$' #,##0.00", 'es_AR');
      txt = total >= 0 ? '+${fmt.format(total)}' : fmt.format(total);
      color = total >= 0 ? Colors.green : Colors.red;
    } else {
      txt = '';
      color = Colors.transparent;
    }
    // --- FIN Lógica de Total ---

    return Padding(
      padding: EdgeInsets.fromLTRB(12, verticalPadding, 12, 6),
      child: Row(
        children: [
          // Layout condicional (sin cambios)
          if (muted)
            Expanded(
              child: Text(range, textAlign: TextAlign.center, style: textStyle),
            ),
          if (!muted) ...[
            Expanded(
              child: Text(range, textAlign: TextAlign.center, style: textStyle),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(/* ... */),
              child: Text(
                txt,
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MonthBanner extends StatelessWidget {
  const _MonthBanner({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final label = DateFormat("MMMM yyyy", 'es_AR').format(date);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      child: Container(
        height: 88,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(.65),
              Theme.of(context).colorScheme.secondary.withOpacity(.45),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(.35),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            _cap(label),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  String _cap(String s) =>
      s.isEmpty ? s : (s[0].toUpperCase() + s.substring(1));
}

class _EmptyMonthPlaceholder extends StatelessWidget {
  const _EmptyMonthPlaceholder({required this.date});
  final DateTime date; // Primer día del mes

  // Helper para calcular el ancho necesario para 2 dígitos (o el número más ancho)
  // Helper para calcular el ancho necesario
  double _calculateNumberWidth(BuildContext context, TextStyle style) {
    // 👇 Obtiene la dirección del texto del contexto
    //    (Directionality.of devuelve dart:ui's TextDirection)
    final ui.TextDirection direction = Directionality.of(context);

    final painter = TextPainter(
      text: TextSpan(text: '00', style: style),
      maxLines: 1,
      // 👇 Usa el tipo con prefijo ui.TextDirection
      textDirection: direction, // <-- Pasar la variable 'direction'
    )..layout();
    return painter.size.width;
  }

  @override
  Widget build(BuildContext context) {
    final weeksInMonth = _weeksInsideMonth(date);
    final monthShort = DateFormat('MMM', 'es_AR').format(date).toLowerCase();
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final textStyle = textTheme.bodyMedium?.copyWith(
      color: cs.onSurface.withOpacity(0.38), // Color con opacidad
      fontFeatures: const [
        FontFeature.tabularFigures(),
      ], // Mantenlo por si ayuda
    );

    // Calcula el ancho necesario para los números basado en el estilo
    // Añadimos un pequeño extra por si acaso
    final double numberWidth = _calculateNumberWidth(context, textStyle!) + 2.0;

    final firstDayOfMonth = DateTime(date.year, date.month, 1);
    final lastDayOfMonth = DateTime(date.year, date.month + 1, 0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center, // Centrado
        children: weeksInMonth.map((weekStart) {
          final weekEnd = _weekEndSunday(weekStart);
          final displayStartDate = weekStart.isBefore(firstDayOfMonth)
              ? firstDayOfMonth
              : weekStart;
          final displayEndDate = weekEnd.isAfter(lastDayOfMonth)
              ? lastDayOfMonth
              : weekEnd;

          // No necesitamos padLeft ahora, el SizedBox se encarga
          final startDayStr = displayStartDate.day.toString();
          final endDayStr = displayEndDate.day.toString();

          // Construye la fila para alinear
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              mainAxisSize:
                  MainAxisSize.min, // Para que la fila no ocupe todo el ancho
              children: [
                Text(
                  '$monthShort ',
                  style: textStyle,
                ), // Nombre del mes + espacio
                // SizedBox con ancho fijo para el primer número, alineado a la derecha
                SizedBox(
                  width: numberWidth,
                  child: Text(
                    startDayStr,
                    style: textStyle,
                    textAlign: TextAlign.right,
                  ),
                ),
                Text(' - ', style: textStyle), // Separador
                // SizedBox con ancho fijo para el segundo número, alineado a la derecha
                SizedBox(
                  width: numberWidth,
                  child: Text(
                    endDayStr,
                    style: textStyle,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
