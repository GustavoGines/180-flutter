import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../auth/auth_state.dart';
import '../../core/models/order.dart';
import 'orders_repository.dart';

// --- Lógica de Estado (sin cambios) ---

enum DateFilter { today, week, month }

final ordersByFilterProvider = FutureProvider.family
    .autoDispose<List<Order>, DateFilter>((ref, filter) async {
      // 1. Obtenemos los pedidos de la API como siempre
      final repository = ref.watch(ordersRepoProvider);
      final now = DateTime.now();
      late DateTime from;
      late DateTime to;

      switch (filter) {
        case DateFilter.today:
          from = now;
          // Hasta el final del día de mañana
          final tomorrow = DateTime(
            now.year,
            now.month,
            now.day,
          ).add(const Duration(days: 1));
          to = DateTime(
            tomorrow.year,
            tomorrow.month,
            tomorrow.day,
            23,
            59,
            59,
          );
          break;
        case DateFilter.week:
          final weekStart = now.subtract(Duration(days: now.weekday - 1));
          from = DateTime(weekStart.year, weekStart.month, weekStart.day);
          to = from.add(const Duration(days: 7));
          break;
        case DateFilter.month:
          from = DateTime(now.year, now.month, 1);
          to = DateTime(now.year, now.month + 1, 1);
          break;
      }
      final orders = await repository.getOrders(from: from, to: to);

      // --- 2. ORDENAMIENTO INTELIGENTE ---
      // Definimos la prioridad de cada estado. Un número menor va primero.
      const statusOrder = {
        'confirmed': 1,
        'ready': 2,
        'delivered': 3,
        'canceled': 4,
      };

      orders.sort((a, b) {
        // Criterio 1: Ordenar por la prioridad del estado
        final priorityA =
            statusOrder[a.status] ?? 99; // 99 para estados desconocidos
        final priorityB = statusOrder[b.status] ?? 99;
        int statusCompare = priorityA.compareTo(priorityB);
        if (statusCompare != 0) {
          return statusCompare;
        }

        // Criterio 2: Si los estados son iguales, ordenar por fecha del evento
        int dateCompare = a.eventDate.compareTo(b.eventDate);
        if (dateCompare != 0) {
          return dateCompare;
        }

        // Criterio 3: Si las fechas son iguales, ordenar por hora de inicio
        return a.startTime.compareTo(b.startTime);
      });

      // 3. Devolvemos la lista ya ordenada
      return orders;
    });

// --- UI Home (igual) ---

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Resumen de Pedidos'),
          actions: [
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'clients':
                    context.push('/clients');
                    break;
                  case 'create_user':
                    context.push('/create_user');
                    break;
                  case 'logout':
                    ref.read(authStateProvider.notifier).logout();
                    break;
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem(
                  value: 'clients',
                  child: ListTile(
                    leading: Icon(Icons.people_outline),
                    title: Text('Clientes'),
                  ),
                ),
                if (authState.user?.isAdmin ?? false)
                  const PopupMenuItem(
                    value: 'create_user',
                    child: ListTile(
                      leading: Icon(Icons.person_add_alt_1),
                      title: Text('Crear Usuario'),
                    ),
                  ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'logout',
                  child: ListTile(
                    leading: Icon(Icons.logout, color: Colors.red),
                    title: Text(
                      'Cerrar Sesión',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Próximos', icon: Icon(Icons.star_border_outlined)),
              Tab(text: 'Semana', icon: Icon(Icons.calendar_view_week)),
              Tab(text: 'Mes', icon: Icon(Icons.calendar_month)),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => context.push('/new_order'),
          child: const Icon(Icons.add),
        ),
        body: const TabBarView(
          children: [
            OrderListView(filter: DateFilter.today),
            OrderListView(filter: DateFilter.week),
            OrderListView(filter: DateFilter.month),
          ],
        ),
      ),
    );
  }
}

// --- OrderListView  ---

class OrderListView extends ConsumerWidget {
  final DateFilter filter;
  const OrderListView({super.key, required this.filter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsyncValue = ref.watch(ordersByFilterProvider(filter));

    return ordersAsyncValue.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) =>
          Center(child: Text('Error al cargar pedidos: $err')),
      data: (orders) {
        if (orders.isEmpty) {
          return const Center(
            child: Text(
              'No hay pedidos para este período.',
              style: TextStyle(fontSize: 16),
            ),
          );
        }
        return RefreshIndicator(
          // CORRECCIÓN MENOR: Usamos ref.refresh que es más simple
          onRefresh: () => ref.refresh(ordersByFilterProvider(filter).future),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 80, top: 8),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              // Prevenimos un error si la lista cambia mientras se construye
              if (index >= orders.length) return const SizedBox.shrink();
              final order = orders[index];

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

                // --- LÓGICA DE BORRADO CORREGIDA Y MÁS ROBUSTA ---
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
                      // Hacemos la llamada a la API y esperamos el resultado
                      await ref.read(ordersRepoProvider).deleteOrder(order.id);
                      // Si la API responde bien, invalidamos el provider para refrescar la lista
                      ref.invalidate(ordersByFilterProvider(filter));
                      // Y mostramos el mensaje de éxito
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Pedido #${order.id} eliminado.'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      // Devolvemos true para que la animación de Dismissible se complete
                      return true;
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error al eliminar: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      // Si la API falla, devolvemos false para que el ítem vuelva a su lugar
                      return false;
                    }
                  }
                  // Si el usuario canceló, el ítem vuelve a su lugar
                  return false;
                },

                // onDismissed ya no es necesario aquí
                child: OrderCard(order: order, filter: filter),
              );
            },
          ),
        );
      },
    );
  }
}

// --- Paleta pastel ---

const _kPastelBabyBlue = Color(0xFFDFF1FF);
const _kPastelMint = Color(0xFFD8F6EC);
const _kPastelSand = Color(0xFFF6EEDF);

const _kInkBabyBlue = Color(0xFF8CC5F5);
const _kInkMint = Color(0xFF83D1B9);
const _kInkSand = Color(0xFFC9B99A);

// Fondos pastel por estado
const _statusPastelBg = <String, Color>{
  'confirmed': _kPastelMint,
  'ready': Color(0xFFFFE6EF), // 🌸 rosa pastel
  'delivered': _kPastelBabyBlue,
  'canceled': Color(0xFFFFE0E0), // 🍓 rojo pastel suave
};

// Acento/borde por estado
const _statusInk = <String, Color>{
  'confirmed': _kInkMint,
  'ready': Color(0xFFF3A9B9), // rosa un poco más saturado
  'delivered': _kInkBabyBlue,
  'canceled': Color(0xFFE57373), // rojo pastel (suave, no chillón)
};

// Traducciones visibles
const _statusTranslations = {
  'confirmed': 'Confirmado',
  'ready': 'Listo',
  'delivered': 'Entregado',
  'canceled': 'Cancelado',
};

// --- OrderCard con estilo pastel ---

class OrderCard extends ConsumerWidget {
  const OrderCard({super.key, required this.order, required this.filter});
  final Order order;
  final DateFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final format = NumberFormat("'\$' #,##0.00", 'es_AR');
    final totalString = format.format(order.total);

    final bg = _statusPastelBg[order.status] ?? _kPastelSand;
    final ink = _statusInk[order.status] ?? _kInkSand;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      color: bg, // fondo pastel
      surfaceTintColor: Colors.transparent, // mantiene el pastel limpio (M3)
      shape: RoundedRectangleBorder(
        side: BorderSide(color: ink.withValues(alpha: 0.45), width: 1.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/order/${order.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Cliente y Total ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      order.client?.name ?? 'Cliente no especificado',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: Colors.black.withValues(alpha: 0.85),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    totalString,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: Colors.black.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // --- Fecha y Hora ---
              _InfoRow(
                icon: Icons.calendar_today,
                text: DateFormat(
                  'EEEE d \'de\' MMMM',
                  'es_AR',
                ).format(order.eventDate),
              ),
              const SizedBox(height: 4),
              _InfoRow(
                icon: Icons.access_time,
                text:
                    '${DateFormat.Hm().format(order.startTime)} - ${DateFormat.Hm().format(order.endTime)}',
              ),

              const Divider(height: 24),

              // --- Estado con chip/selector ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: ink.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: ink.withValues(alpha: 0.35)),
                    ),
                    child: Text(
                      _statusTranslations[order.status] ?? order.status,
                      style: TextStyle(
                        color: ink.withValues(alpha: 0.95),
                        fontWeight: FontWeight.w600,
                        letterSpacing: .2,
                      ),
                    ),
                  ),
                  DropdownButton<String>(
                    value: order.status,
                    underline: const SizedBox(),
                    icon: const Icon(Icons.arrow_drop_down_rounded),
                    items: _statusTranslations.keys.map((String value) {
                      final c = _statusInk[value] ?? _kInkSand;
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(_statusTranslations[value]!),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) async {
                      if (newValue != null && newValue != order.status) {
                        await ref
                            .read(ordersRepoProvider)
                            .updateStatus(order.id, newValue);
                        ref.invalidate(ordersByFilterProvider(filter));
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Reusable row
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.black54),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 15, color: Colors.black87),
          ),
        ),
      ],
    );
  }
}
