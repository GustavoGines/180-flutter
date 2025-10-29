part of '../home_page.dart';

class _UnifiedOrdersList extends ConsumerStatefulWidget {
  const _UnifiedOrdersList({
    required this.itemScrollController,
    required this.itemPositionsListener,
    required this.monthIndexMap,
  });

  final ItemScrollController itemScrollController;
  final ItemPositionsListener itemPositionsListener;
  final Map<DateTime, int> monthIndexMap;

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

  // 👇 2. Pasa el mes ESTÁTICO al constructor del builder
  late final _listBuilder = _FlatListBuilder(
    widget.monthIndexMap,
    _staticCenterMonth, // 👈 Usa el mes estático
    _flatList,
  );

  // 👇 3. _rebuildFlatList ya NO necesita 'selMonth'
  void _rebuildFlatList(List<Order> orders) {
    widget.monthIndexMap.clear();
    _flatList.clear();
    _listBuilder.build(orders: orders); // 👈 Solo pasa los pedidos
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(ordersWindowProvider);
    // final selMonth = ref.watch(selectedMonthProvider); // 👈 Ya no se necesita aquí

    // 👇 4. ESTE LISTENER ES BUENO:
    // Reconstruye la lista si los datos cambian (ej: borrar/editar)
    ref.listen(ordersWindowProvider, (_, next) {
      if (next is AsyncData<List<Order>>) {
        setState(() {
          _rebuildFlatList(next.value);
        });
      }
    });

    // 👇 5. ¡¡ESTE LISTENER ERA EL BUG!!
    // Lo eliminamos por completo. Ya no queremos reconstruir la
    // lista cuando el mes seleccionado cambie.
    /*
    ref.listen(selectedMonthProvider, (_, next) {
      if (ordersAsync is AsyncData<List<Order>>) {
        setState(() {
          _rebuildFlatList(ordersAsync.value, next);
        });
      }
    });
    */

    return ordersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error al cargar pedidos: $err')),
      data: (orders) {
        // 👇 6. Llama a la versión simplificada en la carga inicial
        if (_flatList.isEmpty) {
          _rebuildFlatList(orders);
        }

        return RefreshIndicator(
          onRefresh: () {
            setState(() => _flatList.clear());

            // 👇 7. CORRECCIÓN para 'onRefresh' con AsyncNotifier
            // 1. Invalida el provider para forzar que se reconstruya
            ref.invalidate(ordersWindowProvider);

            // 2. Lee el nuevo 'future' y devuélvelo al RefreshIndicator.
            // Es necesario ignorar esta advertencia específica.
            // ignore: invalid_use_of_protected_member
            return ref.read(ordersWindowProvider.future);
          },
          child: ScrollablePositionedList.builder(
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
                  );
                case _ItemType.dayHeader:
                  return _DateHeaderDelegate(
                    date: item.data,
                  ).build(context, 0.0, false);
                case _ItemType.orderCard:
                  return _buildOrderCard(context, ref, item.data);
                case _ItemType.padding:
                  return SizedBox(height: item.data);
              }
            },
          ),
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
  // summary, // 👈 ELIMINADO
  monthBanner,
  weekSeparator,
  dayHeader,
  orderCard,
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
  final List<_ListItem> flatList;
  // 👇 9. Cambia 'selMonth' por 'staticCenterMonth'
  final DateTime staticCenterMonth;

  _FlatListBuilder(this.monthIndexMap, this.staticCenterMonth, this.flatList);

  // 👇 10. El método build ya NO recibe 'selMonth'
  void build({required List<Order> orders}) {
    // this.selMonth = selMonth; // 👈 LÍNEA ELIMINADA

    final byDay = SplayTreeMap<DateTime, List<Order>>((a, b) => a.compareTo(b));
    for (final o in orders) {
      final k = _dayKey(o.eventDate);
      byDay.putIfAbsent(k, () => []).add(o);
    }

    final weekTotals = <DateTime, double>{};
    for (final o in orders) {
      final ws = _weekStartSunday(o.eventDate);
      weekTotals.update(
        ws,
        (v) => v + (o.total ?? 0),
        ifAbsent: () => (o.total ?? 0),
      );
    }

    // 👇 11. ¡LA SOLUCIÓN!
    // La ventana de 49 meses se construye usando el mes central ESTÁTICO,
    // no el mes seleccionado.
    final allMonthsInWindow = _monthsAroundWindow(staticCenterMonth);

    // Añadimos un padding inicial (como tenías en tus slivers)
    flatList.add(_ListItem(_ItemType.padding, 8.0));

    // Iteramos sobre TODOS los 49 meses
    for (final month in allMonthsInWindow) {
      // (El resto de tu lógica de 'build' va aquí, sin cambios)
      monthIndexMap[month] =
          flatList.length; // 👈 Esto ahora pobla el map completo
      flatList.add(_ListItem(_ItemType.monthBanner, month));

      final weeks = _weeksInsideMonth(month);
      for (final ws in weeks) {
        final we = _weekEndSunday(ws);
        final total = weekTotals[ws] ?? 0;

        bool weekHasOrders = false;
        for (int i = 0; i < 7; i++) {
          final d = ws.add(Duration(days: i));
          if (d.month != month.month) continue;
          if (byDay[_dayKey(d)]?.isNotEmpty == true) {
            weekHasOrders = true;
            break;
          }
        }

        flatList.add(
          _ListItem(_ItemType.weekSeparator, {
            'ws': ws,
            'we': we,
            'total': total,
            'muted':
                !weekHasOrders, // 👈 'muted' se pondrá true si no hay pedidos
          }),
        );

        // Si no hay pedidos en la semana, no intentes dibujar los días
        if (!weekHasOrders) continue;

        for (int i = 0; i < 7; i++) {
          final day = ws.add(Duration(days: i));
          if (day.month != month.month) continue;
          final list = byDay[_dayKey(day)];
          if (list == null || list.isEmpty) continue;

          flatList.add(_ListItem(_ItemType.dayHeader, day));

          for (final order in list) {
            flatList.add(_ListItem(_ItemType.orderCard, order));
          }
        }
      }
    }

    flatList.add(_ListItem(_ItemType.padding, 80.0));
  }
}
