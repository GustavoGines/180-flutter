// ignore_for_file: unnecessary_library_name
part of '../home_page.dart';

// --- (Tu lista de gradientes se mantiene igual) ---
const _vibrantMonthGradients = [
  // Ene: Azul Frío
  LinearGradient(
    colors: [Color(0xFF00c6ff), Color(0xFF0072ff)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  // Feb: Rosa/Rojo
  LinearGradient(
    colors: [Color(0xFFF06292), Color(0xFFE91E63)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  // Mar: Verde Lima
  LinearGradient(
    colors: [Color(0xFFAEEA00), Color(0xFF8BC34A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  // Abr: Naranja
  LinearGradient(
    colors: [Color(0xFFFFD180), Color(0xFFFF9800)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  // May: Cian/Turquesa
  LinearGradient(
    colors: [Color(0xFF18FFFF), Color(0xFF00BCD4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  // Jun: Rosa
  LinearGradient(
    colors: [Color(0xFFFF80AB), Color(0xFFF06292)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  // Jul: Amarillo
  LinearGradient(
    colors: [Color(0xFFFFFF8D), Color(0xFFFFEB3B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  // Ago: Marrón (Tu marca)
  LinearGradient(
    colors: [Color(0xFFA1887F), Color(0xFF7A4A4A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  // Sep: Verde
  LinearGradient(
    colors: [Color(0xFF69F0AE), Color(0xFF4CAF50)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  // Oct: Púrpura
  LinearGradient(
    colors: [Color(0xFFE040FB), Color(0xFF9C27B0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  // Nov: Púrpura/Azul (¡Como tu captura de pantalla!)
  LinearGradient(
    colors: [Color(0xFF7C4DFF), Color(0xFF304FFE)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  // Dic: Rojo/Naranja
  LinearGradient(
    colors: [Color(0xFFFF8A80), Color(0xFFE57373)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
];
// --- FIN LISTA GRADIENTES ---

// (El widget _DateHeader no necesita cambios)
class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.orders});
  final List<Order> orders;

  @override
  Widget build(BuildContext context) {
    final DateTime date = orders.first.eventDate;
    final int count = orders.length;

    String totalString = '';

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
          Text(
            _prettyDayLabel(date),
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: .2,
            ),
          ),
          if (totalString.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Text(
                totalString,
                style: textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant.withOpacity(0.8),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          const Spacer(),
        ],
      ),
    );
  }
}

// (El widget _WeekSeparator no necesita cambios)
class _WeekSeparator extends StatelessWidget {
  const _WeekSeparator({
    required this.weekStart,
    required this.weekEnd,
    required this.total,
    required this.currentDisplayMonth,
    this.muted = false,
  });
  final DateTime weekStart;
  final DateTime weekEnd;
  final double total;
  final DateTime currentDisplayMonth;
  final bool muted;

  @override
  Widget build(BuildContext context) {
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

    final DateTime displayStartDate = weekStart.isBefore(firstDayOfMonth)
        ? firstDayOfMonth
        : weekStart;

    final DateTime displayEndDate = weekEnd.isAfter(lastDayOfMonth)
        ? lastDayOfMonth
        : weekEnd;

    final startDayStr = displayStartDate.day.toString().padLeft(2);
    final endDayStr = displayEndDate.day.toString().padLeft(2);
    final range = '$monthShort $startDayStr - $endDayStr';

    final cs = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: muted
          ? cs.outline.withOpacity(0.6)
          : cs.onSurface.withOpacity(0.7),
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final verticalPadding = muted ? 4.0 : 16.0;

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

    return Padding(
      padding: EdgeInsets.fromLTRB(12, verticalPadding, 12, 6),
      child: Row(
        children: [
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

// --- 👇 AQUÍ ESTÁ EL NUEVO DISEÑO CON GRADIENTE "CLARITO -> OSCURO -> CLARITO" ---
class _MonthBanner extends StatefulWidget {
  const _MonthBanner({required this.date, this.logoImage});

  final DateTime date;
  final ImageProvider? logoImage;

  @override
  State<_MonthBanner> createState() => _MonthBannerState();
}

class _MonthBannerState extends State<_MonthBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = DateFormat(
      "MMMM yyyy",
      'es_AR',
    ).format(widget.date).toUpperCase();

    // 1. Obtenemos los dos colores principales del gradiente del mes
    final LinearGradient originalGradient =
        _vibrantMonthGradients[widget.date.month - 1];

    // Asumimos que el primer color es el MÁS CLARO (ej: 0xFF7C4DFF)
    final Color colorClarito = originalGradient.colors.first;
    // Asumimos que el segundo color es el MÁS OSCURO (ej: 0xFF304FFE)
    final Color colorOscuro = originalGradient.colors.last;

    // 2. --- ¡AQUÍ ESTÁ LA MAGIA! ---
    // Creamos el NUEVO gradiente que pediste: Clarito -> Oscuro -> Clarito
    final newGradient = LinearGradient(
      colors: [
        colorClarito, // "clarito en el logo" (lado izquierdo)
        colorOscuro, // "oscuro en el centro"
        colorClarito, // "comience clarito" (lado derecho)
      ],
      stops: const [
        0.0, // El gradiente empieza en 'clarito'
        0.5, // Llega a 'oscuro' justo en el medio
        1.0, // Termina en 'clarito'
      ],
      begin: Alignment.centerLeft, // Empieza a la izquierda
      end: Alignment.centerRight, // Termina a la derecha
    );

    // 3. Usamos el color oscuro para la sombra
    final shadowColor = colorOscuro;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Container(
        height: 130, // Altura consistente
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          // 4. Aplicamos el NUEVO gradiente "Light-Dark-Light"
          gradient: newGradient,
          boxShadow: [
            BoxShadow(
              color: shadowColor.withOpacity(0.4),
              blurRadius: 12,
              spreadRadius: 2,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          // Recorta el contenido para que respete los bordes
          borderRadius: BorderRadius.circular(16),
          // 5. Usamos el Stack para posicionar el contenido SOBRE el gradiente
          child: Stack(
            children: [
              // --- EL LOGO POSICIONADO ---
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: 12.0,
                  ), // Padding izquierdo
                  child: ScaleTransition(
                    scale: _animation,
                    child: widget.logoImage != null
                        ? Image(
                            image: widget.logoImage!,
                            fit: BoxFit.contain,
                            width: 130,
                            height: 130,
                          )
                        : const SizedBox(width: 120, height: 120),
                  ),
                ),
              ),

              // --- EL TEXTO POSICIONADO ---
              Align(
                alignment: Alignment.centerLeft, // Alineado a la izquierda
                child: Padding(
                  // Lo movemos 90px para que quede DESPUÉS del logo
                  padding: const EdgeInsets.only(left: 130.0),
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 1.1,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          offset: Offset(1, 1),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
// --- FIN DEL NUEVO BANNER ---

// (El widget _EmptyMonthPlaceholder no necesita cambios)
class _EmptyMonthPlaceholder extends StatelessWidget {
  const _EmptyMonthPlaceholder({required this.date});
  final DateTime date;

  double _calculateNumberWidth(BuildContext context, TextStyle style) {
    final ui.TextDirection direction = Directionality.of(context);

    final painter = TextPainter(
      text: TextSpan(text: '00', style: style),
      maxLines: 1,
      textDirection: direction,
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
      color: cs.onSurface.withOpacity(0.38),
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    final double numberWidth = _calculateNumberWidth(context, textStyle!) + 2.0;

    final firstDayOfMonth = DateTime(date.year, date.month, 1);
    final lastDayOfMonth = DateTime(date.year, date.month + 1, 0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: weeksInMonth.map((weekStart) {
          final weekEnd = _weekEndSunday(weekStart);
          final displayStartDate = weekStart.isBefore(firstDayOfMonth)
              ? firstDayOfMonth
              : weekStart;
          final displayEndDate = weekEnd.isAfter(lastDayOfMonth)
              ? lastDayOfMonth
              : weekEnd;

          final startDayStr = displayStartDate.day.toString();
          final endDayStr = displayEndDate.day.toString();

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$monthShort ', style: textStyle),
                SizedBox(
                  width: numberWidth,
                  child: Text(
                    startDayStr,
                    style: textStyle,
                    textAlign: TextAlign.right,
                  ),
                ),
                Text(' - ', style: textStyle),
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
