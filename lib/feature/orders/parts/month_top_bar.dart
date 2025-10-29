part of orders_home;

class _MonthTopBar extends ConsumerStatefulWidget {
  const _MonthTopBar({required this.onSelect});
  final void Function(DateTime) onSelect;

  @override
  ConsumerState<_MonthTopBar> createState() => _MonthTopBarState();
}

class _MonthTopBarState extends ConsumerState<_MonthTopBar> {
  final _ctrl = ScrollController();

  late final List<DateTime> _months;
  final Map<DateTime, GlobalKey> _chipKeys = {};

  bool _didInitialCenter = false;
  DateTime? _lastCentered;

  @override
  void initState() {
    super.initState();

    final initialMonth = ref.read(selectedMonthProvider);
    _months = _monthsAroundWindow(initialMonth);

    for (final m in _months) {
      _chipKeys[m] = GlobalKey();
    }
  }

  String _monthName(DateTime m) =>
      DateFormat('MMM', 'es_AR').format(m).replaceAll('.', '').toUpperCase();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _centerChipAsync(DateTime m, {bool animate = true}) async {
    final monthKey = DateTime(m.year, m.month, 1);

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    final key = _chipKeys[monthKey];
    final ctx = key?.currentContext;
    final ro = ctx?.findRenderObject();

    if (ctx == null || ro == null || !_ctrl.hasClients) {
      if (kDebugMode) {
        print('Error al centrar: no se encontró contexto para $monthKey');
      }
      return;
    }

    final viewport = RenderAbstractViewport.of(ro);

    final target = viewport.getOffsetToReveal(ro, 0.5).offset;
    final clamped = target.clamp(
      _ctrl.position.minScrollExtent,
      _ctrl.position.maxScrollExtent,
    );

    if (_lastCentered == monthKey && (clamped - _ctrl.offset).abs() < 0.5) {
      return;
    }
    _lastCentered = monthKey;

    if (animate) {
      await _ctrl.animateTo(
        clamped,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _ctrl.jumpTo(clamped);
    }
  }

  Widget _buildChip(DateTime m, DateTime selected) {
    final cs = Theme.of(context).colorScheme;
    final isSel = m.year == selected.year && m.month == selected.month;

    final bg = isSel ? cs.primary.withOpacity(.20) : cs.surfaceContainerHighest;
    final brd = isSel ? cs.primary : cs.outlineVariant;
    final txt = isSel ? cs.primary : cs.onSurface.withOpacity(.80);

    return InkWell(
      key: _chipKeys[m],
      borderRadius: BorderRadius.circular(12),

      // 👇 ÚNICO CAMBIO: La lógica de 'onTap'
      onTap: () {
        final firstDay = DateTime(m.year, m.month, 1);

        // 1. ELIMINAMOS el 'await _centerChipAsync'.
        // El 'ref.listen' de abajo se encargará de esto.

        // 2. SOLO notificamos a la página.
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

    if (!_didInitialCenter) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await _centerChipAsync(selected, animate: false);
        _didInitialCenter = true;
      });
    }

    // Este listener ahora es el ÚNICO responsable
    // de centrar la barra de chips.
    ref.listen<DateTime>(selectedMonthProvider, (prev, next) {
      if (!mounted || prev == next) return;
      final targetMonth = DateTime(next.year, next.month, 1);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _centerChipAsync(targetMonth, animate: true);
      });
    });

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
