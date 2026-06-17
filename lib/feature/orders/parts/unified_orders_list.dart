part of '../home_page.dart';

class _UnifiedOrdersList extends ConsumerStatefulWidget {
  const _UnifiedOrdersList({
    required this.itemScrollController,
    required this.itemPositionsListener,
    required this.monthIndexMap,
    required this.dayIndexMap,
    this.logoImageProvider,
  });

  final ItemScrollController itemScrollController;
  final ItemPositionsListener itemPositionsListener;
  final Map<DateTime, int> monthIndexMap;
  final Map<DateTime, int> dayIndexMap;
  final ImageProvider? logoImageProvider;

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
    dayIndexMap: widget.dayIndexMap,
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
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(ordersWindowProvider);

    // Escuchar cambios para programar el salto solo si es necesario
    ref.listen(ordersWindowProvider, (_, next) {
      if (next is AsyncData<List<Order>>) {
        setState(() {
          _rebuildFlatList(next.value);
        });
      }
    });

    return ordersAsync.when(
      loading: () {
        // En _UnifiedOrdersList, el 'loading' nunca debería ejecutarse
        // porque este widget solo se llama en el bloque 'data' de HomePage.
        // Pero si lo estás usando en otro lado, se mantiene.
        return const Center(child: CircularProgressIndicator());
      },
      error: (err, _) => Center(child: Text('Error al cargar pedidos: $err')),
      data: (orders) {
        int initialIndex = 0;

        // 1. LÓGICA SÍNCRONA DE CONSTRUCCIÓN Y CÁLCULO DEL ÍNDICE
        if (_flatList.isEmpty) {
          _rebuildFlatList(orders);

          final now = DateTime.now();
          final currentMonthKey = DateTime(now.year, now.month, 1);
          final todayKey = DateTime(now.year, now.month, now.day);

          final dayIndex = widget.dayIndexMap[todayKey];

          // El índice de inicio se calcula aquí antes de renderizar la lista.
          initialIndex =
              dayIndex ?? (widget.monthIndexMap[currentMonthKey] ?? 0);
        }

        // 2. USAR initialScrollIndex Y initialAlignment
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(ordersWindowProvider);
            try {
              await ref.read(ordersWindowProvider.future);
            } catch (_) {}
          },
          child: ScrollablePositionedList.builder(
            itemScrollController: widget.itemScrollController,
            itemPositionsListener: widget.itemPositionsListener,
            physics: const AlwaysScrollableScrollPhysics(),

            // ✅ Usamos el índice calculado solo en el primer render
            initialScrollIndex: initialIndex,
            initialAlignment: 0.15,

            itemCount: _flatList.length,
            itemBuilder: (context, index) {
              // ... (Resto del itemBuilder)
              final item = _flatList[index];
              switch (item.type) {
                case _ItemType.monthBanner:
                  return _MonthBanner(
                    date: item.data,
                    logoImage: widget.logoImageProvider, // 👈 Pasa el logo aquí
                  );

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

                case _ItemType.dayHeader:
                  return _DateHeader(orders: item.data);
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
}
// --- Widgets que extrajiste de los Slivers ---

Widget _buildOrderCard(BuildContext context, WidgetRef ref, Order order) {
  // (Tu código de _buildOrderCard va aquí, sin cambios)
  return Dismissible(
    key: ValueKey(order.id),
    direction: DismissDirection.horizontal,
    background: Container(
      color: Colors.green.shade600,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_outline, color: Colors.white),
          SizedBox(width: 8),
          Text(
            'MARCAR PAGADO',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    ),
    secondaryBackground: Container(
      color: Colors.red.shade700,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            'ELIMINAR',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          SizedBox(width: 8),
          Icon(Icons.delete_forever, color: Colors.white),
        ],
      ),
    ),
    confirmDismiss: (direction) async {
      if (direction == DismissDirection.startToEnd) {
        if (order.isPaid) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Este pedido ya está pagado.'),
              backgroundColor: Colors.orange,
            ),
          );
          return false;
        }

        try {
          final updatedOrder = await ref.read(ordersRepoProvider).markAsPaid(order.id);
          if (updatedOrder != null) {
            await ref.read(ordersWindowProvider.notifier).updateOrder(updatedOrder);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Pedido #${order.id} marcado como pagado.'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          }
          return false; // Retornamos false para que la tarjeta no desaparezca, solo se actualice
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error al marcar pagado: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return false;
        }
      } else if (direction == DismissDirection.endToStart) {
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
            await ref.read(ordersWindowProvider.notifier).deleteOrder(order.id);

            if (!context.mounted) return true;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Pedido #${order.id} eliminado.'),
                backgroundColor: Colors.green,
              ),
            );
            return true;
          } catch (e) {
            if (!context.mounted) return false;
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
      }
      return false;
    },
    child: OrderCard(order: order),
  );
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
                  // Suma solo si cumple la lógica de "Ingreso Real" (Entregado y Pagado)
                  if (order.status == OrderStatus.delivered && order.isPaid) {
                    final v = order.total ?? 0;
                    if (v >= 0) {
                      weekTotalForThisMonth += v;
                    }
                  }
                }
              }
            }
          }
          // --- FIN NUEVA LÓGICA ---

          // 'muted' ahora usa la variable local
          final bool muted = !weekHasOrdersInThisMonth;

          // 1. Guardamos el índice ANTES de añadir el separador de semana
          final int weekSeparatorIndex = flatList.length;

          flatList.add(
            _ListItem(_ItemType.weekSeparator, {
              'ws': ws,
              'we': we,
              'total': weekTotalForThisMonth,
              'muted': muted,
              'current_month': month,
            }),
          );

          // 2. ELIMINAMOS el 'if (muted) continue;' de aquí.
          //    El loop de días ahora se ejecuta SIEMPRE.

          // 3. Iteramos los 7 días de la semana
          for (int i = 0; i < 7; i++) {
            final day = ws.add(Duration(days: i));

            // Filtramos días de otro mes
            if (day.month != month.month) continue;

            final list = byDay[day];

            if (list == null || list.isEmpty) {
              // 4. DÍA VACÍO: Apuntamos al índice del separador de semana
              dayIndexMap[day] = weekSeparatorIndex;
            } else {
              // 5. DÍA CON PEDIDOS:
              // Guardamos el índice de su futuro DayHeader
              final int dayHeaderIndex = flatList.length;
              dayIndexMap[day] = dayHeaderIndex;

              // 6. PERO, solo añadimos los items (headers y cards)
              //    si la semana NO está "muted" (colapsada).
              if (!muted) {
                flatList.add(_ListItem(_ItemType.dayHeader, list));

                for (final order in list) {
                  flatList.add(_ListItem(_ItemType.orderCard, order));
                }
              }
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
