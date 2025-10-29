// ignore: use_string_in_part_of_directives
part of orders_home;

class _MonthTopBar extends ConsumerStatefulWidget {
  const _MonthTopBar({super.key, required this.onSelect});
  final void Function(DateTime) onSelect;

  @override
  ConsumerState<_MonthTopBar> createState() => _MonthTopBarState();
}

class _MonthTopBarState extends ConsumerState<_MonthTopBar> {
  final _ctrl = ScrollController();
  late final List<DateTime> _months;
  final Map<DateTime, GlobalKey> _chipKeys = {};

  final bool _didInitialScroll = false; // 🔹 flag importante

  @override
  void initState() {
    super.initState();

    final initialMonth = ref.read(selectedMonthProvider);
    _months = _monthsAroundWindow(initialMonth);

    for (final m in _months) {
      _chipKeys[m] = GlobalKey();
    }

    // 🔥 Esperar un frame adicional antes de centrar
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;

      final selected = ref.read(selectedMonthProvider);
      await scrollToCurrentMonth(selected, animate: false);
    });
  }

  Future<void> scrollToCurrentMonth(
    DateTime month, {
    bool animate = true,
  }) async {
    if (!_ctrl.hasClients) return;

    final key = _chipKeys[DateTime(month.year, month.month, 1)];
    if (key == null) return;

    // Esperar hasta que el chip tenga contexto
    BuildContext? ctx;
    for (int i = 0; i < 10; i++) {
      ctx = key.currentContext;
      if (ctx != null) break;
      await Future.delayed(const Duration(milliseconds: 40));
    }
    if (ctx == null || !mounted) return;

    final box = ctx.findRenderObject() as RenderBox?;
    final parentBox = context.findRenderObject() as RenderBox?;
    if (box == null || parentBox == null) return;

    final position = box.localToGlobal(Offset.zero, ancestor: parentBox);
    final viewportWidth = parentBox.size.width;

    // 🌀 Movimiento centrado tipo “carrusel”
    final targetOffset =
        _ctrl.offset + position.dx - (viewportWidth / 2 - box.size.width / 2);

    final clamped = targetOffset.clamp(
      _ctrl.position.minScrollExtent,
      _ctrl.position.maxScrollExtent,
    );

    if (animate) {
      await _ctrl.animateTo(
        clamped,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOutCubicEmphasized, // más natural, tipo carrusel
      );
    } else {
      _ctrl.jumpTo(clamped);
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
      key: _chipKeys[m],
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        final firstDay = DateTime(m.year, m.month, 1);
        widget.onSelect(firstDay);
      },
      child: Container(
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

    // 🔁 Si cambia el mes, centramos el chip correspondiente
    ref.listen<DateTime>(selectedMonthProvider, (prev, next) {
      if (!mounted || prev == next) return;
      final target = DateTime(next.year, next.month, 1);
      scrollToCurrentMonth(target, animate: true);
    });

    // 🔥 Si al inicio aún no se centró, lo hacemos (fallback)
    if (!_didInitialScroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final current = DateTime(selected.year, selected.month, 1);
        scrollToCurrentMonth(current);
      });
    }

    return Container(
      height: 60,
      alignment: Alignment.centerLeft,
      child: ListView(
        controller: _ctrl,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: _months.expand((m) {
          return [_buildChip(m, selected), const SizedBox(width: 8)];
        }).toList()..removeLast(),
      ),
    );
  }
}
