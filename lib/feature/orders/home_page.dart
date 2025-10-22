import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../auth/auth_state.dart';
import '../../core/models/order.dart';
import 'orders_repository.dart';

// --- Lógica de Estado con Riverpod ---

enum DateFilter { today, week, month }

// 1. CONVERTIMOS EL PROVIDER A .family
//    Ahora cada pestaña puede pedir sus propios datos de forma independiente.
final ordersByFilterProvider = FutureProvider.family
    .autoDispose<List<Order>, DateFilter>((ref, filter) async {
      final repository = ref.watch(ordersRepoProvider);
      final now = DateTime.now().toUtc();
      late DateTime from;
      late DateTime to;

      switch (filter) {
        case DateFilter.today:
          from = DateTime.utc(now.year, now.month, now.day);
          to = from.add(const Duration(days: 1));
          break;
        case DateFilter.week:
          final weekStart = now.subtract(Duration(days: now.weekday - 1));
          from = DateTime.utc(weekStart.year, weekStart.month, weekStart.day);
          to = from.add(const Duration(days: 7));
          break;
        case DateFilter.month:
          from = DateTime.utc(now.year, now.month, 1);
          to = DateTime.utc(now.year, now.month + 1, 1);
          break;
      }
      return repository.getOrders(from: from, to: to);
    });

// --- UI de la Página Principal ---

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    // 2. USAMOS DefaultTabController PARA MANEJAR LAS PESTAÑAS
    return DefaultTabController(
      length: 3, // El número de pestañas
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
          // 3. AGREGAMOS EL TabBar EN LA PARTE INFERIOR DEL APPBAR
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Hoy', icon: Icon(Icons.today)),
              Tab(text: 'Semana', icon: Icon(Icons.calendar_view_week)),
              Tab(text: 'Mes', icon: Icon(Icons.calendar_month)),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => context.push('/new_order'),
          child: const Icon(Icons.add),
        ),
        // 4. EL CUERPO AHORA ES UN TabBarView CON LAS PÁGINAS DESLIZABLES
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

// --- WIDGET REUTILIZABLE PARA MOSTRAR LA LISTA DE PEDIDOS ---
//    Esta es la vista para CADA una de las pestañas.
class OrderListView extends ConsumerWidget {
  final DateFilter filter;
  const OrderListView({super.key, required this.filter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Cada vista observa el provider con su propio filtro
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
          onRefresh: () async {
            // Invalidamos el provider específico de esta pestaña
            ref.invalidate(ordersByFilterProvider(filter));
            await ref.read(ordersByFilterProvider(filter).future);
          },
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 80, top: 8),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return OrderCard(order: order);
            },
          ),
        );
      },
    );
  }
}

// --- OrderCard Widget (sin cambios) ---
class OrderCard extends StatelessWidget {
  const OrderCard({super.key, required this.order});
  final Order order;

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'confirmed':
        return Colors.green.shade100;
      case 'delivered':
        return Colors.blue.shade100;
      case 'canceled':
        return Colors.red.shade100;
      default:
        return Colors.grey.shade200;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Usamos un patrón personalizado para asegurar que el símbolo '$' esté al principio.
    // Creamos un formato con un patrón personalizado.
    // '¤' es el símbolo de moneda, '#' y '0' son los números.
    final format = NumberFormat("'\$' #,##0.00", 'es_AR');
    final totalString = format.format(order.total);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 2,
      child: ListTile(
        title: Text(order.client?.name ?? 'Cliente no especificado'),
        subtitle: Text(
          'Fecha: ${DateFormat('dd/MM/yy HH:mm').format(order.startTime)}\nTotal: $totalString',
        ),
        trailing: Chip(
          label: Text(
            (order.status).toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          backgroundColor: _getStatusColor(order.status),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onTap: () {
          context.push('/order/${order.id}');
        },
      ),
    );
  }
}
