// Archivo: lib/feature/clients/trashed_clients_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'clients_repository.dart';

class TrashedClientsPage extends ConsumerWidget {
  const TrashedClientsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTrashed = ref.watch(getTrashedClientsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Papelera de Clientes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(getTrashedClientsProvider),
          ),
        ],
      ),
      body: asyncTrashed.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (clients) {
          if (clients.isEmpty) {
            return const Center(child: Text('La papelera está vacía.'));
          }

          return ListView.builder(
            itemCount: clients.length,
            itemBuilder: (context, index) {
              final client = clients[index];
              final deletedAt = client.deletedAt != null
                  ? DateFormat('dd/MM/yyyy').format(client.deletedAt!)
                  : 'Fecha desconocida';

              return ListTile(
                title: Text(client.name),
                subtitle: Text('Eliminado el: $deletedAt'),
                trailing: FilledButton.tonal(
                  child: const Text('Restaurar'),
                  onPressed: () async {
                    try {
                      await ref
                          .read(clientsRepoProvider)
                          .restoreClient(client.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Cliente restaurado'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      // Refrescar esta lista y la lista principal
                      ref.invalidate(getTrashedClientsProvider);
                      ref.invalidate(
                        clientsRepoProvider,
                      ); // Para la página de búsqueda
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
