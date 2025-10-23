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

// --- OrderListView (igual) ---

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
          onRefresh: () async {
            ref.invalidate(ordersByFilterProvider(filter));
            await ref.read(ordersByFilterProvider(filter).future);
          },
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 80, top: 8),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return OrderCard(order: order, filter: filter);
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
