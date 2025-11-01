part of '../home_page.dart';

class _UnifiedOrdersList extends ConsumerStatefulWidget {
  const _UnifiedOrdersList({
    required this.itemScrollController,
    required this.itemPositionsListener,
    required this.monthIndexMap,
    required this.dayIndexMap, // 👈 Ya lo tenías, está OK
  });

  final ItemScrollController itemScrollController;
  final ItemPositionsListener itemPositionsListener;
  final Map<DateTime, int> monthIndexMap;
  final Map<DateTime, int> dayIndexMap; // 👈 Ya lo tenías, está OK

  @override
  ConsumerState<_UnifiedOrdersList> createState() => _UnifiedOrdersListState();
}

class _UnifiedOrdersListState extends ConsumerState<_UnifiedOrdersList> {
  final List<_ListItem> _flatList = [];

  // 👇 1. Define el mes central ESTÁTICO (basado en 'hoy')
  late final DateTime _staticCenterMonth = () {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }();

  // 👇 2. Pasa el mes ESTÁTICO y el dayIndexMap al constructor del builder
  late final _listBuilder = _FlatListBuilder(
    monthIndexMap: widget.monthIndexMap,
    dayIndexMap: widget.dayIndexMap, // 👈 AÑADIDO: Pasa el mapa de días
    staticCenterMonth: _staticCenterMonth,
    flatList: _flatList,
  );

  // 👇 3. _rebuildFlatList ahora también limpia el dayIndexMap
  void _rebuildFlatList(List<Order> orders) {
    widget.monthIndexMap.clear();
    widget.dayIndexMap.clear(); // 👈 AÑADIDO: Limpia el mapa de días
    _flatList.clear();
    _listBuilder.build(orders: orders);
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(ordersWindowProvider);
    // final selMonth = ref.watch(selectedMonthProvider); // 👈 Ya no se necesita aquí

    // 👇 ESTE LISTENER ES BUENO:
    // Reconstruye la lista si los datos cambian (ej: borrar/editar)
    ref.listen(ordersWindowProvider, (_, next) {
      if (next is AsyncData<List<Order>>) {
        setState(() {
          _rebuildFlatList(next.value);
        });
      }
    });

    return ordersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error al cargar pedidos: $err')),
      data: (orders) {
        // 👇 Llama a la versión simplificada en la carga inicial
        if (_flatList.isEmpty) {
          _rebuildFlatList(orders);
        }

        // 👇 MODIFICADO: Se eliminó el RefreshIndicator de aquí.
        // Ahora solo devolvemos la lista.
        return ScrollablePositionedList.builder(
          itemScrollController: widget.itemScrollController,
          itemPositionsListener: widget.itemPositionsListener,
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: _flatList.length,
          itemBuilder: (context, index) {
            final item = _flatList[index];

            // Lógica de traducción
            switch (item.type) {
              case _ItemType.monthBanner:
                return _MonthBanner(date: item.data);
              case _ItemType.weekSeparator:
                return _WeekSeparator(
                  weekStart: item.data['ws'],
                  weekEnd: item.data['we'],
                  total: item.data['total'],
                  muted: item.data['muted'],
                  currentDisplayMonth: item.data['current_month'] as DateTime,
                );

              case _ItemType.emptyMonthPlaceholder:
                return _EmptyMonthPlaceholder(date: item.data);
              // 👇 --- FIN ---

              case _ItemType.dayHeader:
                return _DateHeader(orders: item.data);
              case _ItemType.orderCard:
                return _buildOrderCard(context, ref, item.data);
              case _ItemType.padding:
                return SizedBox(height: item.data);
            }
          },
        );
      },
    );
  }
  // --- Widgets que extrajiste de los Slivers ---

  Widget _buildOrderCard(BuildContext context, WidgetRef ref, Order order) {
    // (Tu código de _buildOrderCard va aquí, sin cambios)
    return Dismissible(
      key: ValueKey(order.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red.shade700,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'ELIMINAR',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.delete_forever, color: Colors.white),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        final bool? didConfirm = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Confirmar Eliminación'),
              content: const Text(
                '¿Estás seguro de que quieres eliminar este pedido?',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Eliminar'),
                ),
              ],
            );
          },
        );

        if (didConfirm == true) {
          try {
            // 👇 8. CORRECCIÓN DE TIPO (usa 'order.id' que es un 'int')
            await ref.read(ordersWindowProvider.notifier).deleteOrder(order.id);

            if (!context.mounted) return true; // Chequeo de seguridad
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Pedido #${order.id} eliminado.'),
                backgroundColor: Colors.green,
              ),
            );
            return true;
          } catch (e) {
            if (!context.mounted) return false; // Chequeo de seguridad
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error al eliminar: $e'),
                backgroundColor: Colors.red,
              ),
            );
            return false;
          }
        }
        return false;
      },
      child: OrderCard(order: order),
    );
  }
}

// -------------------------------------------------------------------
// 11. Lógica para "aplanar" la lista (nuevo)
// -------------------------------------------------------------------

// Define los tipos de items en tu lista
enum _ItemType {
  padding,
  monthBanner,
  weekSeparator,
  dayHeader,
  orderCard,
  emptyMonthPlaceholder,
}

// Un objeto que representa un item en la lista
class _ListItem {
  final _ItemType type;
  final dynamic data;
  _ListItem(this.type, this.data);
}

// Esta clase toma toda tu lógica de 'build' y 'slivers'
// y la convierte en una List<_ListItem>
class _FlatListBuilder {
  final Map<DateTime, int> monthIndexMap;
  final Map<DateTime, int> dayIndexMap; // 👈 AÑADIDO
  final List<_ListItem> flatList;
  final DateTime staticCenterMonth;

  _FlatListBuilder({
    required this.monthIndexMap,
    required this.dayIndexMap,
    required this.staticCenterMonth,
    required this.flatList,
  });

  void build({required List<Order> orders}) {
    // --- Lógica de SplayTree (Se Mantiene) ---
    final byDay = SplayTreeMap<DateTime, List<Order>>((a, b) => a.compareTo(b));
    for (final o in orders) {
      final k = _dayKey(o.eventDate);
      byDay.putIfAbsent(k, () => []).add(o);
    }

    final allMonthsInWindow = _monthsAroundWindow(staticCenterMonth);
    flatList.add(_ListItem(_ItemType.padding, 8.0));

    // Iteramos sobre TODOS los 49 meses
    for (final month in allMonthsInWindow) {
      monthIndexMap[month] = flatList.length;
      flatList.add(
        _ListItem(_ItemType.monthBanner, month),
      ); // Banner se añade siempre

      // 1. Revisa si el mes tiene CUALQUIER pedido
      final bool monthHasOrders = byDay.keys.any(
        (day) => day.year == month.year && day.month == month.month,
      );

      if (monthHasOrders) {
        // 2. SI TIENE PEDIDOS: Usa la lógica de semanas
        final weeks = _weeksInsideMonth(month);
        for (final ws in weeks) {
          // 'ws' es el Lunes de inicio de semana
          final we = _weekEndSunday(ws);

          // 👇 --- ¡NUEVA LÓGICA DE CÁLCULO DE TOTAL! ---
          double weekTotalForThisMonth = 0;
          bool weekHasOrdersInThisMonth = false;

          // Itera los 7 días de esta semana
          for (int i = 0; i < 7; i++) {
            final day = ws.add(Duration(days: i));

            // ¡IMPORTANTE! Solo suma si el día pertenece al mes que estamos viendo
            if (day.month == month.month) {
              final ordersForThisDay =
                  byDay[day]; // Usa 'byDay' que ya está calculado
              if (ordersForThisDay != null && ordersForThisDay.isNotEmpty) {
                weekHasOrdersInThisMonth = true;
                for (final order in ordersForThisDay) {
                  // Suma solo si el total es positivo (como en tus providers)
                  final v = order.total ?? 0;
                  if (v >= 0) {
                    weekTotalForThisMonth += v;
                  }
                }
              }
            }
          }
          // --- FIN NUEVA LÓGICA ---

          // 'muted' ahora usa la variable local
          final bool muted = !weekHasOrdersInThisMonth;

          flatList.add(
            _ListItem(_ItemType.weekSeparator, {
              'ws': ws,
              'we': we,
              'total': weekTotalForThisMonth, // <-- Usa el total corregido
              'muted': muted,
              'current_month': month,
            }),
          );

          // Si no hay pedidos en la semana, no intentes dibujar los días
          if (muted) continue;

          // Este código solo se ejecuta si la semana tiene pedidos
          for (int i = 0; i < 7; i++) {
            final day = ws.add(Duration(days: i));
            if (day.month != month.month) continue; // Filtra días del otro mes
            final list = byDay[day];
            if (list == null || list.isEmpty) continue;

            flatList.add(_ListItem(_ItemType.dayHeader, list));

            for (final order in list) {
              flatList.add(_ListItem(_ItemType.orderCard, order));
            }
          }
        }
      } else {
        // 3. SI NO TIENE PEDIDOS: Añade UN SOLO placeholder para el mes
        flatList.add(_ListItem(_ItemType.emptyMonthPlaceholder, month));
      }
    }

    flatList.add(_ListItem(_ItemType.padding, 80.0));
  }
}
