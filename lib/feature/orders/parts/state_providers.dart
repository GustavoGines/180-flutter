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
const int _kBackMonths = 24;
const int _kFwdMonths = 24;

/// ===============================================================
/// Ventana de pedidos (MODERNO: AsyncNotifier)
/// ===============================================================

// 1. Esta es la clase Notifier
class OrdersWindowNotifier extends rp.AsyncNotifier<List<Order>> {
  // El método 'build' hace lo mismo que tu FutureProvider:
  // Carga los datos iniciales.
  @override
  Future<List<Order>> build() async {
    final repository = ref.watch(ordersRepoProvider);
    final now = DateTime.now();
    final centerMonth = DateTime(now.year, now.month, 1);

    // 👇 RECUERDA: Usamos +_kFwdMonths (49 meses), no +_kFwdMonths+1 (50)
    final from = DateTime(
      centerMonth.year,
      centerMonth.month - _kBackMonths,
      1,
    );
    final to = DateTime(centerMonth.year, centerMonth.month + _kFwdMonths, 1);

    final orders = await repository.getOrders(from: from, to: to);

    // Tu lógica de sort (sin cambios)
    const statusOrder = {
      'confirmed': 1,
      'ready': 2,
      'delivered': 3,
      'canceled': 4,
    };
    orders.sort((a, b) {
      final dayCmp =
          DateTime(
            a.eventDate.year,
            a.eventDate.month,
            a.eventDate.day,
          ).compareTo(
            DateTime(b.eventDate.year, b.eventDate.month, b.eventDate.day),
          );
      if (dayCmp != 0) return dayCmp;
      final timeCmp = a.startTime.compareTo(b.startTime);
      if (timeCmp != 0) return timeCmp;
      final pa = statusOrder[a.status] ?? 99;
      final pb = statusOrder[b.status] ?? 99;
      return pa.compareTo(pb);
    });

    return orders;
  }

  // 👇 2. MÉTODO PÚBLICO para actualizar un estado
  Future<void> updateOrderStatus(int orderId, String newStatus) async {
    // Obtenemos el repositorio
    final repository = ref.read(ordersRepoProvider);

    // Obtenemos el estado actual de la lista
    // 'await future' es la forma segura de leer el valor de un AsyncNotifier
    final previousState = await future;

    try {
      // 1. Llamamos a la API/DB
      await repository.updateStatus(orderId, newStatus);

      // 2. Si la API tuvo éxito, actualizamos el estado local
      state = AsyncData(
        previousState.map((order) {
          if (order.id == orderId) {
            // Asumimos que tu modelo Order tiene .copyWith()
            return order.copyWith(status: newStatus);
          }
          return order;
        }).toList(),
      );
    } catch (e, s) {
      // 3. Si la API falla, lanzamos un error
      // El 'state' no se actualiza, la UI sigue igual.
      state = AsyncError(e, s);
      // Opcional: podrías revertir al estado anterior si hiciste cambios optimistas
    }
  }

  // 👇 3. MÉTODO PÚBLICO para eliminar un pedido
  Future<void> deleteOrder(int orderId) async {
    final repository = ref.read(ordersRepoProvider);
    final previousState = await future;

    try {
      // 1. Llamamos a la API/DB
      await repository.deleteOrder(orderId);

      // 2. Si la API tuvo éxito, actualizamos el estado local
      state = AsyncData(
        previousState.where((order) => order.id != orderId).toList(),
      );
    } catch (e, s) {
      // 3. Si la API falla, lanzamos un error
      state = AsyncError(e, s);
    }
  }
}

// 4. Esta es la nueva definición del provider
final ordersWindowProvider =
    rp.AsyncNotifierProvider.autoDispose<OrdersWindowNotifier, List<Order>>(
      OrdersWindowNotifier.new,
    );

/// ===============================================================
/// 👇 NUEVO: Provider intermedio para los pedidos del mes
/// ===============================================================
final selectedMonthOrdersProvider = rp.Provider.autoDispose<List<Order>>((ref) {
  final ordersAsync = ref.watch(ordersWindowProvider);
  final selMonth = ref.watch(selectedMonthProvider);

  // 👇 USA .when() EN LUGAR DE .valueOrNull
  return ordersAsync.when(
    data: (orders) {
      // --- Si hay datos, filtramos ---
      final mesFrom = DateTime(selMonth.year, selMonth.month, 1);
      final mesTo = DateTime(
        selMonth.year,
        selMonth.month + 1,
        1,
      ).subtract(const Duration(seconds: 1));

      return orders.where((o) {
        final d = _dayKey(o.eventDate);
        return !(d.isBefore(mesFrom) || d.isAfter(mesTo));
      }).toList();
    },
    // --- Si está cargando, devuelve lista vacía ---
    loading: () {
      return [];
    },
    // --- Si hay un error, devuelve lista vacía ---
    error: (err, stack) {
      // Opcional: puedes loguear el error si quieres
      // print('Error en selectedMonthOrdersProvider: $err');
      return [];
    },
  );
});

/// ===============================================================
/// Cálculo de ingresos para el mes seleccionado
/// ===============================================================
final monthlyIncomeProvider = rp.Provider.autoDispose<double>((ref) {
  // 1. Escucha al nuevo provider filtrado
  final monthOrders = ref.watch(selectedMonthOrdersProvider);

  double ingresosMes = 0;
  for (final o in monthOrders) {
    final v = o.total ?? 0;
    if (v >= 0) {
      ingresosMes += v;
    }
  }
  return ingresosMes;
});

/// ===============================================================
/// 👇 NUEVO: Conteo de pedidos (ingresos) para el mes
/// ===============================================================
final monthlyOrdersCountProvider = rp.Provider.autoDispose<int>((ref) {
  // 1. Escucha al nuevo provider filtrado
  final monthOrders = ref.watch(selectedMonthOrdersProvider);

  int count = 0;
  for (final o in monthOrders) {
    final v = o.total ?? 0;
    if (v >= 0) {
      count++;
    }
  }
  return count;
});
