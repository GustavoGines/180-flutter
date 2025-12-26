import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/models/order.dart';
import 'orders_repository.dart';

final ordersProvider = FutureProvider.family<List<Order>, int>((
  ref,
  offset,
) async {
  final now = DateTime.now();
  final day = DateTime(
    now.year,
    now.month,
    now.day,
  ).add(Duration(days: offset));
  final dayTo = day.add(const Duration(days: 1));
  return ref.read(ordersRepoProvider).getOrders(from: day, to: dayTo);
});

class OrderList extends ConsumerWidget {
  final int dayOffset;
  const OrderList({super.key, required this.dayOffset});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ordersProvider(dayOffset));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (orders) => ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: orders.length,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final o = orders[i];
          return ListTile(
            title: Text(
              '${DateFormat.Hm().format(o.startTime)} – ${DateFormat.Hm().format(o.endTime)} • ${o.status.toUpperCase()}',
            ),
            subtitle: Text('Cliente #${o.clientId} • ${o.notes ?? ""}'),
            trailing: Text(NumberFormat(r"'$' #,##0", 'es_AR').format(o.total)),
          );
        },
      ),
    );
  }
}
