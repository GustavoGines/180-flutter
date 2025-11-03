import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart'; // Necesitarás flutter_hooks
// ignore: legacy_Linter_file_Name
import 'package:flutter_riverpod/legacy.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pasteleria_180_flutter/feature/clients/clients_repository.dart';
import 'package:go_router/go_router.dart';
import 'dart:async'; // Para el Debouncer

// Un simple Debouncer para no buscar en cada tecleo
class Debouncer {
  final int milliseconds;
  Timer? _timer;

  Debouncer({required this.milliseconds});

  run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }

  dispose() {
    _timer?.cancel();
  }
}

// Provider para el query de búsqueda
final clientSearchQueryProvider = StateProvider<String>((ref) => '');

class ClientsPage extends HookConsumerWidget {
  const ClientsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Controlador para el TextField
    final searchController = useTextEditingController();
    // 2. Debouncer
    final debouncer = useMemoized(() => Debouncer(milliseconds: 300), []);
    // 3. Observamos el query de búsqueda
    final searchQuery = ref.watch(clientSearchQueryProvider);
    // 4. Observamos el provider que trae los datos
    final asyncClients = ref.watch(clientsListProvider(searchQuery));

    // 5. --- OBTENER COLORES DEL TEMA ---
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    // (Se eliminó 'darkBrown')
    // --- FIN ---

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clientes'),
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
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Ver papelera',
            onPressed: () => context.push('/clients/trashed'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar',
            onPressed: () => ref.invalidate(clientsListProvider(searchQuery)),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                labelText: 'Buscar por nombre o teléfono...',
                // --- ADAPTADO AL TEMA ---
                prefixIcon: Icon(Icons.search, color: cs.primary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide(color: cs.outline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide(color: cs.primary, width: 2.0),
                ),
                // --- FIN ADAPTACIÓN ---
              ),
              onChanged: (query) {
                // Usamos el debouncer para actualizar el provider
                debouncer.run(() {
                  ref.read(clientSearchQueryProvider.notifier).state = query;
                });
              },
            ),
          ),
          // 6. Lista de resultados reactiva
          Expanded(
            child: asyncClients.when(
              loading: () => Center(
                // --- ADAPTADO AL TEMA ---
                // El color por defecto es cs.primary
                child: CircularProgressIndicator(),
                // --- FIN ADAPTACIÓN ---
              ),
              error: (err, stack) =>
                  Center(child: Text('Error al cargar clientes: $err')),
              data: (clients) {
                if (clients.isEmpty) {
                  return Center(
                    child: Text(
                      searchQuery.isEmpty
                          ? 'No hay clientes registrados.'
                          : 'No se encontraron clientes.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.refresh(clientsListProvider(searchQuery).future),
                  child: ListView.separated(
                    itemCount: clients.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 16, endIndent: 16),
                    itemBuilder: (_, i) {
                      final c = clients[i];
                      return ListTile(
                        title: Text(c.name),
                        subtitle: Text(
                          '${c.phone ?? "Sin teléfono"} • ${c.email ?? "Sin email"}',
                        ),
                        leading: CircleAvatar(
                          // --- ADAPTADO AL TEMA ---
                          backgroundColor: cs.primaryContainer,
                          foregroundColor: cs.onPrimaryContainer,
                          // --- FIN ADAPTACIÓN ---
                          child: Text(
                            c.name.isNotEmpty ? c.name[0].toUpperCase() : 'C',
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          // --- ADAPTADO AL TEMA ---
                          color: cs.onSurfaceVariant, // Color neutral
                          // --- FIN ADAPTACIÓN ---
                        ),
                        onTap: () => context.push('/clients/${c.id}'),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/clients/new'),
        // --- ADAPTADO AL TEMA ---
        // (Estilo "branded" FAB)
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        child: const Icon(Icons.add),
        // --- FIN ADAPTACIÓN ---
      ),
    );
  }
}
