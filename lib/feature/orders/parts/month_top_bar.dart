part of orders_home;

class _MonthTopBar extends ConsumerStatefulWidget {
  const _MonthTopBar({required this.onSelect});
  final void Function(DateTime) onSelect;

  @override
  ConsumerState<_MonthTopBar> createState() => _MonthTopBarState();
}

class _MonthTopBarState extends ConsumerState<_MonthTopBar> {
  final _ctrl = ScrollController();

  // --- 👇 CAMBIOS AQUÍ ---
  // 1. Declaramos la lista de meses y las keys como 'late final'
  //    (se inicializarán en initState)
  late final List<DateTime> _months;
  final Map<DateTime, GlobalKey> _chipKeys = {};
  // --- Fin Cambios ---

  bool _didInitialCenter = false;
  DateTime? _lastCentered;

  List<DateTime> _monthsAround(DateTime center) {
    final centerMonth = DateTime(center.year, center.month, 1);
    final start = DateTime(
      centerMonth.year,
      centerMonth.month - _kBackMonths,
      1,
    );
    final total = _kBackMonths + _kFwdMonths + 1;

    return List.generate(
      total,
      (i) => DateTime(start.year, start.month + i, 1),
    );
  }

  // --- 👇 CAMBIO AQUÍ ---
  // 2. Creamos initState para generar la lista UNA SOLA VEZ
  @override
  void initState() {
    super.initState();

    // Obtenemos el mes inicial usando ref.read (NO watch)
    final initialMonth = ref.read(selectedMonthProvider);

    // Generamos la lista de meses estática
    _months = _monthsAround(initialMonth);

    // Generamos las GlobalKeys estáticas
    for (final m in _months) {
      _chipKeys[m] = GlobalKey();
    }
  }
  // --- Fin Cambios ---

  String _monthName(DateTime m) =>
      DateFormat('MMM', 'es_AR').format(m).replaceAll('.', '').toUpperCase();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // Esta función de centrado está perfecta
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

    // Tuve que cambiar esto (surfaceVariant) porque el 'fileName' que me pasaste lo tenía así.
    // Si usas Material 3, 'surfaceVariant' es lo normal.
    final bg = isSel ? cs.primary.withOpacity(.20) : cs.surfaceContainerHighest;
    final brd = isSel ? cs.primary : cs.outlineVariant;
    final txt = isSel ? cs.primary : cs.onSurface.withOpacity(.80);

    return InkWell(
      key: _chipKeys[m], // Usa la key estática
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final firstDay = DateTime(m.year, m.month, 1);
        // 1. Centra el chip
        await _centerChipAsync(m, animate: true);
        // 2. Notifica a la página (esto disparará el rebuild,
        //    pero ahora el rebuild es seguro)
        if (mounted) widget.onSelect(firstDay);
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
    // Solo 'miramos' el mes seleccionado para saber CUAL pintar
    final selected = ref.watch(selectedMonthProvider);

    // --- 👇 CAMBIO AQUÍ ---
    // 3. Ya NO generamos la lista de meses ni las keys aquí.
    //    Usamos la lista estática '_months' de nuestro state.
    // final months = _monthsAround(selected); // <--- ELIMINADO
    // _chipKeys.clear(); // <--- ELIMINADO
    // --- Fin Cambios ---

    if (!_didInitialCenter) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        // Centramos el mes seleccionado INICIAL
        await _centerChipAsync(selected, animate: false);
        _didInitialCenter = true;
      });
    }

    // Este listener se dispara cuando la lista PRINCIPAL scrollea
    // y actualiza el provider.
    ref.listen<DateTime>(selectedMonthProvider, (prev, next) {
      if (!mounted || prev == next) return;
      final targetMonth = DateTime(next.year, next.month, 1);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // Centramos el chip (esto es seguro ahora)
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
        // 4. Usamos la lista estática '_months'
        children: _months.expand((m) {
          return [_buildChip(m, selected), const SizedBox(width: 8)];
        }).toList()..removeLast(),
      ),
    );
  }
}
