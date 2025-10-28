// ignore_for_file: use_string_in_part_of_directives
part of orders_home;

/// ===============================================================
/// Mes seleccionado (MODERNO: NotifierProvider)
/// - Estado = primer día del mes
/// - Métodos: setTo/next/prev (lógica fuera de la UI)
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
// Años atrás (en meses)
const int _kBackMonths = 33; // 2 años
// Años adelante (en meses)
const int _kFwdMonths = 50; // 3 años

/// ===============================================================
/// Ventana de pedidos (SIMPLE: FutureProvider)
/// - Carga pedidos entre [sel-6m, sel+6m] y ordena ascendente
/// - Refrescar: ref.invalidate(ordersWindowProvider)
/// ===============================================================
final ordersWindowProvider = rp.FutureProvider.autoDispose<List<Order>>((
  ref,
) async {
  final repository = ref.watch(ordersRepoProvider);
  // 1. NO mires 'selectedMonthProvider'. Usa DateTime.now() como centro.
  final now = DateTime.now();
  final centerMonth = DateTime(now.year, now.month, 1);

  // 2. Carga la ventana completa UNA SOLA VEZ
  final from = DateTime(centerMonth.year, centerMonth.month - _kBackMonths, 1);
  final to = DateTime(centerMonth.year, centerMonth.month + _kFwdMonths + 1, 1);

  final orders = await repository.getOrders(from: from, to: to);

  // Orden ascendente por día, luego hora, luego prioridad de estado
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
