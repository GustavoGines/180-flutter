// ignore: use_string_in_part_of_directives
part of orders_home;

class _MonthTopBar extends ConsumerStatefulWidget {
  const _MonthTopBar({super.key, required this.onSelect});
  final void Function(DateTime) onSelect;

  @override
  ConsumerState<_MonthTopBar> createState() => _MonthTopBarState();
}

class _MonthTopBarState extends ConsumerState<_MonthTopBar> {
  // 1. USA EL CONTROLADOR DE 'ScrollablePositionedList'
  final _itemScrollController = ItemScrollController();
  late final List<DateTime> _months;

  @override
  void initState() {
    super.initState();

    final initialMonth = ref.read(selectedMonthProvider);
    _months = _monthsAroundWindow(initialMonth);

    // ⛔️ Ya no hay 'Future.delayed' aquí.
  }

  // 4. FUNCIÓN DE SCROLL NUEVA Y SIMPLE
  Future<void> scrollToCurrentMonth(
    DateTime month, {
    bool animate = true,
  }) async {
    final index = _months.indexWhere(
      (m) => m.year == month.year && m.month == month.month,
    );

    if (index == -1) {
      debugPrint("--- [SCROLL] Error: No se encontró el índice para $month");
      return;
    }

    debugPrint("--- [SCROLL] Scrolleando al ÍNDICE: $index ($month)");

    if (animate) {
      await _itemScrollController.scrollTo(
        index: index,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOutCubicEmphasized,
        alignment: 0.5, // 0.5 = centrado
      );
    } else {
      _itemScrollController.jumpTo(
        index: index,
        alignment: 0.5, // 0.5 = centrado
      );
    }
  }

  String _monthName(DateTime m) =>
      DateFormat('MMM', 'es_AR').format(m).replaceAll('.', '').toUpperCase();

  Widget _buildChip(DateTime m, DateTime selected) {
    final cs = Theme.of(context).colorScheme;
    final isSel = m.year == selected.year && m.month == selected.month;

    final bg = isSel ? cs.primary.withOpacity(.20) : cs.surfaceContainerHighest;
    final brd = isSel ? cs.primary : cs.outlineVariant;
    final txt = isSel ? cs.primary : cs.onSurface.withOpacity(.80);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        final firstDay = DateTime(m.year, m.month, 1);
        widget.onSelect(firstDay);
        // AÑADIDO: También animamos al centro al hacer tap
        scrollToCurrentMonth(firstDay, animate: true);
      },
      child: Container(
        // ... (Tu 'Container' y 'Column' del chip no cambian) ...
        constraints: const BoxConstraints(minWidth: 80),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: brd, width: 1),
          boxShadow: const [
            BoxShadow(
              blurRadius: 8,
              offset: Offset(0, 2),
              color: Colors.black12,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _monthName(m),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: .6,
                color: txt,
                fontSize: 12,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              '${m.year}',
              style: TextStyle(
                color: txt.withOpacity(.85),
                fontSize: 10.5,
                height: 1.0,
                fontWeight: FontWeight.w600,
                letterSpacing: .2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(selectedMonthProvider);

    // Esta lógica se disparará CADA VEZ que el provider cambie
    // (excepto la primera vez, que es manejada por HomePage)
    ref.listen<DateTime>(selectedMonthProvider, (prev, next) {
      // Si el mes no cambió (ej. en la carga inicial), no hace nada
      if (!mounted || prev == next) return;

      final target = DateTime(next.year, next.month, 1);

      // Espera a que el build termine ANTES de scrollear
      // (Esto es por si acaso, pero es buena práctica)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          scrollToCurrentMonth(target, animate: true);
        }
      });
    });

    return Container(
      height: 60,
      alignment: Alignment.centerLeft,
      // 7. USA 'ScrollablePositionedList.builder'
      child: ScrollablePositionedList.builder(
        itemScrollController: _itemScrollController, // Asigna el controlador
        itemCount: _months.length, // Usa la longitud de la lista
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemBuilder: (context, index) {
          final m = _months[index]; // Obtiene el mes por índice

          // Devuelve el chip con su espaciado
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _buildChip(m, selected),
          );
        },
      ),
    );
  }
}
