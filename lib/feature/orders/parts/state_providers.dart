// ignore_for_file: use_string_in_part_of_directives
part of orders_home;

/// ===============================================================
/// Mes seleccionado (MODERNO: NotifierProvider)
/// ===============================================================
class SelectedMonth extends rp.Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  void setTo(DateTime m) => state = DateTime(m.year, m.month, 1);
  void next() => state = DateTime(state.year, state.month + 1, 1);
  void prev() => state = DateTime(state.year, state.month - 1, 1);
}

final selectedMonthProvider = rp.NotifierProvider<SelectedMonth, DateTime>(
  SelectedMonth.new,
);

/// Ventana de meses alrededor del seleccionado
const int _kBackMonths = 33;
const int _kFwdMonths = 50;

/// ===============================================================
/// Ventana de pedidos (SIMPLE: FutureProvider)
/// ===============================================================
final ordersWindowProvider = rp.FutureProvider.autoDispose<List<Order>>((
  ref,
) async {
  final repository = ref.watch(ordersRepoProvider);
  final now = DateTime.now();
  final centerMonth = DateTime(now.year, now.month, 1);

  final from = DateTime(centerMonth.year, centerMonth.month - _kBackMonths, 1);
  final to = DateTime(centerMonth.year, centerMonth.month + _kFwdMonths + 1, 1);

  final orders = await repository.getOrders(from: from, to: to);

  // (Tu lógica de 'sort' va aquí, sin cambios)
  const statusOrder = {
    'confirmed': 1,
    'ready': 2,
    'delivered': 3,
    'canceled': 4,
  };

  orders.sort((a, b) {
    // día ↑
    final dayCmp = DateTime(
      a.eventDate.year,
      a.eventDate.month,
      a.eventDate.day,
    ).compareTo(DateTime(b.eventDate.year, b.eventDate.month, b.eventDate.day));
    if (dayCmp != 0) return dayCmp;

    // hora ↑
    final timeCmp = a.startTime.compareTo(b.startTime);
    if (timeCmp != 0) return timeCmp;

    // estado como desempate
    final pa = statusOrder[a.status] ?? 99;
    final pb = statusOrder[b.status] ?? 99;
    return pa.compareTo(pb);
  });

  return orders;
});

/// ===============================================================
/// Cálculo de ingresos para el mes seleccionado
/// ===============================================================
final monthlyIncomeProvider = rp.Provider.autoDispose<double>((ref) {
  final ordersAsync = ref.watch(ordersWindowProvider);
  final selMonth = ref.watch(selectedMonthProvider);

  return ordersAsync.when(
    data: (orders) {
      double ingresosMes = 0;
      final mesFrom = DateTime(selMonth.year, selMonth.month, 1);
      final mesTo = DateTime(
        selMonth.year,
        selMonth.month + 1,
        1,
      ).subtract(const Duration(seconds: 1));

      for (final o in orders) {
        final d = _dayKey(o.eventDate);
        if (d.isBefore(mesFrom) || d.isAfter(mesTo)) continue;
        final v = o.total ?? 0;

        if (v >= 0) {
          ingresosMes += v;
        }
      }
      return ingresosMes;
    },
    loading: () => 0.0,
    error: (_, __) => 0.0,
  );
});

/// ===============================================================
/// 👇 NUEVO: Conteo de pedidos (ingresos) para el mes
/// ===============================================================
final monthlyOrdersCountProvider = rp.Provider.autoDispose<int>((ref) {
  final ordersAsync = ref.watch(ordersWindowProvider);
  final selMonth = ref.watch(selectedMonthProvider);

  return ordersAsync.when(
    data: (orders) {
      int count = 0;
      final mesFrom = DateTime(selMonth.year, selMonth.month, 1);
      final mesTo = DateTime(
        selMonth.year,
        selMonth.month + 1,
        1,
      ).subtract(const Duration(seconds: 1));

      for (final o in orders) {
        final d = _dayKey(o.eventDate);
        if (d.isBefore(mesFrom) || d.isAfter(mesTo)) continue;
        final v = o.total ?? 0;

        // Contamos solo los pedidos que son ingresos
        if (v >= 0) {
          count++;
        }
      }
      return count;
    },
    loading: () => 0,
    error: (_, __) => 0,
  );
});
