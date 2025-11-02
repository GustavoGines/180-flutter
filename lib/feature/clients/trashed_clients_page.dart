// Archivo: lib/feature/clients/presentation/trashed_clients_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:pasteleria_180_flutter/core/models/client.dart';
import 'package:pasteleria_180_flutter/feature/clients/clients_repository.dart';

class TrashedClientsPage extends ConsumerWidget {
  const TrashedClientsPage({super.key});

  Future<void> _handleForceDelete(
    BuildContext context,
    WidgetRef ref,
    Client client,
  ) async {
    // 1. Pedir una confirmación MÁS FUERTE
    final didConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          '¿ELIMINAR PERMANENTEMENTE?',
          style: TextStyle(color: Colors.red),
        ),
        content: Text(
          'Estás a punto de eliminar a ${client.name} para siempre. Esta acción no se puede deshacer.\n\n¿Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const Text('ELIMINAR'),
          ),
        ],
      ),
    );

    if (didConfirm != true) return;

    // 2. Intentar el borrado
    try {
      await ref.read(clientsRepoProvider).forceDeleteClient(client.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cliente eliminado permanentemente'),
            backgroundColor: Colors.green,
          ),
        );
      }
      // Refrescar la lista de la papelera
      ref.invalidate(trashedClientsProvider); // <-- NOMBRE CORREGIDO
    } catch (e) {
      // 3. Manejar errores (especialmente el 409)
      String errorMsg = 'Error al eliminar: $e';
      if (e is DioException && e.response?.data['message'] != null) {
        errorMsg = e.response!.data['message'];
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // <-- NOMBRE CORREGIDO
    final asyncTrashed = ref.watch(trashedClientsProvider);
    const Color darkBrown = Color(0xFF7A4A4A);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Papelera de Clientes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.invalidate(trashedClientsProvider), // <-- NOMBRE CORREGIDO
          ),
        ],
      ),
      body: asyncTrashed.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: darkBrown)),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (clients) {
          if (clients.isEmpty) {
            return const Center(child: Text('La papelera está vacía.'));
          }

          return RefreshIndicator(
            onRefresh: () => ref.refresh(
              trashedClientsProvider.future,
            ), // <-- NOMBRE CORREGIDO
            child: ListView.builder(
              itemCount: clients.length,
              itemBuilder: (context, index) {
                final client = clients[index];
                final deletedAt = client.deletedAt != null
                    ? DateFormat('dd/MM/yyyy').format(client.deletedAt!)
                    : 'Fecha desconocida';

                return ListTile(
                  title: Text(
                    client.name,
                    style: const TextStyle(
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  subtitle: Text('Eliminado el: $deletedAt'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Botón Restaurar
                      FilledButton.tonal(
                        child: const Text('Restaurar'),
                        onPressed: () async {
                          try {
                            await ref
                                .read(clientsRepoProvider)
                                .restoreClient(client.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Cliente restaurado'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                            // Refrescar ambas listas
                            ref.invalidate(
                              trashedClientsProvider,
                            ); // <-- NOMBRE CORREGIDO
                            ref.invalidate(
                              clientsListProvider,
                            ); // <-- Refrescar lista principal
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                      ),
                      // Botón Eliminar Definitivamente
                      IconButton(
                        icon: Icon(
                          Icons.delete_forever,
                          color: Colors.red.shade700,
                        ),
                        tooltip: 'Eliminar permanentemente',
                        onPressed: () =>
                            _handleForceDelete(context, ref, client),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
