import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../core/models/order.dart';
import '../orders/orders_repository.dart';

class ClientDetailPage extends ConsumerWidget {
  final int id;
  const ClientDetailPage({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Ideal: backend con GET /orders?client_id=:id
    // Si no, traemos rango amplio y filtramos por clientId.
    final repo = OrdersRepository();

    return Scaffold(
      appBar: AppBar(title: Text('Cliente #$id')),
      body: FutureBuilder<List<Order>>(
        future: repo.getOrders(
          from: DateTime.now().subtract(const Duration(days: 60)),
          to: DateTime.now().add(const Duration(days: 365)),
        ),
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          final all = snap.data ?? [];
          final orders = all.where((o) => o.clientId == id).toList();
          if (orders.isEmpty) return const Center(child: Text('Sin pedidos'));

          return ListView.separated(
            itemCount: orders.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final o = orders[i];
              return ListTile(
                title: Text('${o.eventDate} ${o.startTime}-${o.endTime}'),
                subtitle: Text(o.status),
                trailing: Text('\$${o.total}'),
              );
            },
          );
        },
      ),
    );
  }
}
