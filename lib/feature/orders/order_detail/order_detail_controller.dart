import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/order.dart';
import '../../../core/enums/order_status.dart';
import '../orders_repository.dart';
import '../home_page.dart';
import '../order_detail_page.dart';

class OrderDetailController {
  final WidgetRef ref;

  OrderDetailController(this.ref);
  
  // ...


  Future<void> handleMarkAsPaid(BuildContext context, Order order) async {
    final cs = Theme.of(context).colorScheme;
    try {
      final Order? updatedOrder = await ref.read(ordersRepoProvider).markAsPaid(order.id);
      if (updatedOrder != null) {
        await ref.read(ordersWindowProvider.notifier).updateOrder(updatedOrder);
      }
      ref.invalidate(orderByIdProvider(order.id));

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pedido marcado como pagado.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al marcar pago: $e', style: TextStyle(color: cs.onError)),
          backgroundColor: cs.error,
        ),
      );
    }
  }

  Future<void> handleMarkAsUnpaid(BuildContext context, Order order) async {
    final cs = Theme.of(context).colorScheme;

    final bool confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Confirmar Desmarcar Pago'),
            content: const Text(
              'El pedido dejará de figurar como pagado. (El saldo/depósito no se modificará automáticamente). ¿Continuar?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Confirmar'),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      try {
        final Order? updatedOrder = await ref.read(ordersRepoProvider).markAsUnpaid(order.id);
        if (updatedOrder != null) {
          await ref.read(ordersWindowProvider.notifier).updateOrder(updatedOrder);
        }
        ref.invalidate(orderByIdProvider(order.id));

        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pedido marcado como NO pagado.')),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al desmarcar: $e', style: TextStyle(color: cs.onError)),
            backgroundColor: cs.error,
          ),
        );
      }
    }
  }

  Future<void> handleChangeStatus(BuildContext context, Order order, OrderStatus newStatus) async {
    final cs = Theme.of(context).colorScheme;
    try {
      final Order? updatedOrder = await ref.read(ordersRepoProvider).updateStatus(order.id, newStatus.name);
      if (updatedOrder != null) {
        await ref.read(ordersWindowProvider.notifier).updateOrder(updatedOrder);
      }
      ref.invalidate(orderByIdProvider(order.id));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Estado actualizado.'), duration: Duration(seconds: 2)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar estado: $e', style: TextStyle(color: cs.onError)),
            backgroundColor: cs.error,
          ),
        );
      }
      ref.invalidate(orderByIdProvider(order.id));
    }
  }

  void showDeleteConfirmationDialog(BuildContext context, Order order) {
    final cs = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final isDeletingProvider = StateProvider<bool>((_) => false);

        return Consumer(
          builder: (context, dialogRef, child) {
            final isDeleting = dialogRef.watch(isDeletingProvider);

            return AlertDialog(
              title: const Text('Confirmar Eliminación'),
              content: const Text(
                '¿Estás seguro de que quieres eliminar este pedido de forma permanente? Esta acción no se puede deshacer y borrará las fotos asociadas.',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: isDeleting ? null : () => Navigator.of(context).pop(),
                  child: Text('Cancelar', style: TextStyle(color: cs.onSurfaceVariant)),
                ),
                FilledButton.icon(
                  icon: isDeleting
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: cs.onError),
                        )
                      : const Icon(Icons.warning_amber),
                  label: Text(isDeleting ? 'Eliminando...' : 'Eliminar Definitivamente'),
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.error,
                    foregroundColor: cs.onError,
                    disabledBackgroundColor: cs.error.withValues(alpha: 0.5),
                  ),
                  onPressed: isDeleting
                      ? null
                      : () async {
                          dialogRef.read(isDeletingProvider.notifier).state = true;
                          try {
                            await ref.read(ordersWindowProvider.notifier).deleteOrder(order.id);

                            if (context.mounted) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Pedido eliminado con éxito.')),
                              );
                              context.go('/');
                            }
                          } catch (e) {
                            if (context.mounted) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error al eliminar: $e', style: TextStyle(color: cs.onError)),
                                  backgroundColor: cs.error,
                                ),
                              );
                            }
                          }
                        },
                ),
              ],
            );
          },
        );
      },
    );
  }
}
