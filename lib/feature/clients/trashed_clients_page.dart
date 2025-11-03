// Archivo: lib/feature/clients/presentation/trashed_clients_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:pasteleria_180_flutter/core/models/client.dart';
import 'package:pasteleria_180_flutter/feature/clients/clients_repository.dart';

class TrashedClientsPage extends ConsumerWidget {
  const TrashedClientsPage({super.key});

  // --- Helper de SnackBar adaptado al tema ---
  void _showSnackbar(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    if (!context.mounted) return;
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: isError ? TextStyle(color: cs.onError) : null,
        ),
        backgroundColor: isError ? cs.error : null,
      ),
    );
  }
  // --- Fin Helper ---

  Future<void> _handleForceDelete(
    BuildContext context,
    WidgetRef ref,
    Client client,
  ) async {
    // --- OBTENER TEMA ANTES DE DIÁLOGO ---
    final cs = Theme.of(context).colorScheme;

    // 1. Pedir una confirmación MÁS FUERTE
    final didConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          '¿ELIMINAR PERMANENTEMENTE?',
          // --- ADAPTADO AL TEMA ---
          style: TextStyle(color: cs.error),
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
            // --- ADAPTADO AL TEMA ---
            style: FilledButton.styleFrom(
              backgroundColor: cs.error,
              foregroundColor: cs.onError,
            ),
            child: const Text('ELIMINAR'),
          ),
        ],
      ),
    );

    if (didConfirm != true) return;

    // 2. Intentar el borrado
    try {
      await ref.read(clientsRepoProvider).forceDeleteClient(client.id);

      // --- USA EL HELPER ADAPTADO ---
      _showSnackbar(context, 'Cliente eliminado permanentemente');

      // Refrescar la lista de la papelera
      ref.invalidate(trashedClientsProvider); // <-- NOMBRE CORREGIDO
    } catch (e) {
      // 3. Manejar errores (especialmente el 409)
      String errorMsg = 'Error al eliminar: $e';
      if (e is DioException && e.response?.data['message'] != null) {
        errorMsg = e.response!.data['message'];
      }

      // --- USA EL HELPER ADAPTADO ---
      _showSnackbar(context, errorMsg, isError: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // --- OBTENER DATOS DEL TEMA ---
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final asyncTrashed = ref.watch(trashedClientsProvider);
    // (Se eliminó 'darkBrown')

    return Scaffold(
      appBar: AppBar(
        title: const Text('Papelera de Clientes'),
        // --- ADAPTADO AL TEMA ---
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 1,
        titleTextStyle: tt.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: cs.onSurface,
        ),
        actionsIconTheme: IconThemeData(color: cs.onSurfaceVariant),
        // --- FIN ADAPTACIÓN ---
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
            // --- ADAPTADO AL TEMA ---
            const Center(child: CircularProgressIndicator()),
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
                    style: TextStyle(
                      // --- ADAPTADO AL TEMA ---
                      decoration: TextDecoration.lineThrough,
                      color: cs.onSurfaceVariant.withOpacity(0.7),
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

                            // --- USA EL HELPER ADAPTADO ---
                            _showSnackbar(context, 'Cliente restaurado');

                            // Refrescar ambas listas
                            ref.invalidate(
                              trashedClientsProvider,
                            ); // <-- NOMBRE CORREGIDO
                            ref.invalidate(
                              clientsListProvider,
                            ); // <-- Refrescar lista principal
                          } catch (e) {
                            // --- USA EL HELPER ADAPTADO ---
                            _showSnackbar(context, 'Error: $e', isError: true);
                          }
                        },
                      ),
                      // Botón Eliminar Definitivamente
                      IconButton(
                        icon: Icon(
                          Icons.delete_forever,
                          // --- ADAPTADO AL TEMA ---
                          color: cs.error,
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
