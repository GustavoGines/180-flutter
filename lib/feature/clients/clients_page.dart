// clients_page.dart (CON CAMBIOS)

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
// ignore: legacy_Linter_file_Name

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pasteleria_180_flutter/core/ui/skeleton.dart';
import 'package:pasteleria_180_flutter/core/models/client.dart'; // <-- AÑADIDO
import 'package:pasteleria_180_flutter/core/utils/client_dialogs.dart'; // <-- AÑADIDO
import 'package:pasteleria_180_flutter/feature/clients/clients_repository.dart';
import 'package:go_router/go_router.dart';
import 'dart:async'; // Para el Debouncer
import 'package:pasteleria_180_flutter/core/utils/debouncer.dart';
import 'package:pasteleria_180_flutter/core/utils/snackbar_helper.dart';

// --- AÑADIDOS PARA SPEED DIAL ---
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:collection/collection.dart'; // Para .firstWhereOrNull
import 'package:dio/dio.dart'; // Para manejo de errores
// --- FIN DE AÑADIDOS ---


// Provider para el query de búsqueda
// --- ❗️ CAMBIO AQUÍ: Añadido .autoDispose ---
final clientSearchQueryProvider = StateProvider.autoDispose<String>(
  (ref) => '',
);

final selectedClientsProvider = StateProvider.autoDispose<Set<int>>(
  (ref) => {},
);
// -----------------------------------------

class ClientsPage extends HookConsumerWidget {
  const ClientsPage({super.key});

  // --- Helper de SnackBar (copiado de otros archivos) ---


  // --- LÓGICA DE "DESDE CONTACTOS" (Adaptada de new_order_page) ---

  Future<void> _selectClientFromContacts(
    BuildContext context,
    WidgetRef ref,
  ) async {
    // 1. Pedir Permiso de Contactos
    if (!await FlutterContacts.requestPermission(readonly: true)) {
      if (!context.mounted) return;
      context.showCustomSnackbar('Permiso de contactos denegado.', isError: true);
      await openAppSettings(); // Sugerir abrir configuración
      return;
    }

    // 2. Abrir Selector Nativo
    final Contact? contact = await FlutterContacts.openExternalPick();

    if (contact != null) {
      // 3. Extraer datos y normalizar
      final String name = contact.displayName;
      final String? phone =
          contact.phones.isNotEmpty ? contact.phones.first.number : null;

      if (phone == null) {
        if (!context.mounted) return;
        context.showCustomSnackbar(
          'El contacto seleccionado no tiene número de teléfono.',
          isError: true,
        );
        return;
      }

      // 4. Intentar buscar si el cliente ya existe por teléfono
      final existingClients =
          await ref.read(clientsRepoProvider).searchClients(query: phone);
      final existingClient = existingClients.firstWhereOrNull(
        (c) => c.phone == phone,
      );

      if (existingClient != null) {
        // 5. Cliente ya existe: navegar a su detalle
        if (context.mounted) {
          context.showCustomSnackbar('Cliente "${existingClient.name}" ya existe.');
          context.push('/clients/${existingClient.id}');
        }
      } else {
        // 6. Cliente no existe: crear el nuevo cliente
        if (!context.mounted) return;
        _createClientFromData(context, ref, name: name, phone: phone);
      }
    }
  }

  // --- Helper: Crear Cliente (Adaptado de new_order_page) ---
  Future<void> _createClientFromData(
    BuildContext context,
    WidgetRef ref, {
    required String name,
    String? phone,
  }) async {
    if (name.trim().isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    Client? newClient;
    String? errorMessage;

    try {
      newClient = await ref.read(clientsRepoProvider).createClient({
        'name': name.trim(),
        'phone': phone?.trim(),
      });
    } on DioException catch (e) {
      // Si es 409 (cliente borrado), manejamos con diálogo de restauración
      if (e.response?.statusCode == 409 && e.response?.data['client'] != null) {
        if (context.mounted) Navigator.pop(context); // Cierra el loader
        final clientData = e.response?.data['client'];
        final clientToRestore = Client.fromJson(
          (clientData as Map).map((k, v) => MapEntry(k.toString(), v)),
        );
        if (!context.mounted) return;
        final restored = await ClientDialogs.showRestoreDialog(context, ref, clientToRestore);
        if (restored) {
            // Already handled by ClientDialogs
        }
        return; // Sale del try/catch
      }
      errorMessage =
          e.response?.data['message'] as String? ?? 'Error al crear cliente.';
    } catch (e) {
      errorMessage = e.toString();
    }

    if (context.mounted) Navigator.pop(context); // Cerrar loader

    if (newClient != null && context.mounted) {
        context.showCustomSnackbar('Cliente creado con éxito');
      final currentQuery = ref.read(clientSearchQueryProvider);
      ref.invalidate(clientsListProvider(currentQuery));
      if (currentQuery.isNotEmpty) {
        // También invalida la lista vacía por si volvemos sin filtro
        ref.invalidate(clientsListProvider(''));
      }
      context.push(
        '/clients/${newClient.id}',
      ); // Navega al detalle del nuevo cliente
    } else if (errorMessage != null && context.mounted) {
        context.showCustomSnackbar(errorMessage, isError: true);
    }
  }



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
    
    // 5. Estado de selección múltiple
    final selectedClients = ref.watch(selectedClientsProvider);
    final isSelectionMode = selectedClients.isNotEmpty;

    // --- LÓGICA PARA RESETEAR EL CAMPO DE TEXTO ---
    // Si el provider se resetea a '', limpiamos el controlador
    ref.listen(clientSearchQueryProvider, (_, next) {
      if (next.isEmpty) {
        searchController.clear();
      }
    });
    // --- FIN ---

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(isSelectionMode ? '${selectedClients.length} seleccionados' : 'Clientes'),
        backgroundColor: isSelectionMode ? cs.primaryContainer : cs.surface,
        foregroundColor: isSelectionMode ? cs.onPrimaryContainer : cs.onSurface,
        elevation: 1,
        titleTextStyle: tt.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: isSelectionMode ? cs.onPrimaryContainer : cs.onSurface,
        ),
        actionsIconTheme: IconThemeData(color: isSelectionMode ? cs.onPrimaryContainer : cs.onSurfaceVariant),
        actions: isSelectionMode
            ? [
                IconButton(
                  icon: const Icon(Icons.delete),
                  tooltip: 'Eliminar seleccionados',
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('¿Eliminar clientes?'),
                        content: Text('¿Seguro que deseas mover ${selectedClients.length} clientes a la papelera?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true), 
                            style: TextButton.styleFrom(foregroundColor: Colors.red),
                            child: const Text('Eliminar')
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      if (!context.mounted) return;
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => const Center(child: CircularProgressIndicator()),
                      );
                      try {
                        for (final id in selectedClients) {
                          await ref.read(clientsRepoProvider).deleteClient(id);
                        }
                        if (context.mounted) Navigator.pop(context); // Cerrar loader
                        if (context.mounted) context.showCustomSnackbar('${selectedClients.length} clientes eliminados.');
                        ref.read(selectedClientsProvider.notifier).state = {}; // Limpiar selección
                        ref.invalidate(clientsListProvider(searchQuery));
                      } catch (e) {
                        if (context.mounted) Navigator.pop(context); // Cerrar loader
                        if (context.mounted) context.showCustomSnackbar('Error al eliminar: $e', isError: true);
                      }
                    }
                  },
                ),
              ]
            : [
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
                prefixIcon: Icon(Icons.search, color: cs.primary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide(color: cs.outline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide(color: cs.primary, width: 2.0),
                ),
              ),
              onChanged: (query) {
                debouncer.run(() {
                  ref.read(clientSearchQueryProvider.notifier).state = query;
                });
              },
            ),
          ),
          Expanded(
            child: asyncClients.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16.0),
                child: SkeletonList(itemCount: 8, itemHeight: 70.0),
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
                      final isSelected = selectedClients.contains(c.id);
                      
                      return ListTile(
                        selected: isSelected,
                        selectedTileColor: cs.primaryContainer.withAlpha(77), // 0.3 * 255 = 76.5
                        title: Text(c.name),
                        subtitle: Text(
                          '${c.phone ?? "Sin teléfono"} • ${c.email ?? "Sin email"}',
                        ),
                        leading: isSelectionMode
                            ? Checkbox(
                                value: isSelected,
                                onChanged: (val) {
                                  final currentSet = Set<int>.from(selectedClients);
                                  if (val == true) {
                                    currentSet.add(c.id);
                                  } else {
                                    currentSet.remove(c.id);
                                  }
                                  ref.read(selectedClientsProvider.notifier).state = currentSet;
                                },
                              )
                            : CircleAvatar(
                                backgroundColor: cs.primaryContainer,
                                foregroundColor: cs.onPrimaryContainer,
                                child: Text(
                                  c.name.isNotEmpty ? c.name[0].toUpperCase() : 'C',
                                ),
                              ),
                        trailing: isSelectionMode ? null : Icon(
                          Icons.chevron_right,
                          color: cs.onSurfaceVariant,
                        ),
                        onLongPress: () {
                          if (!isSelectionMode) {
                            ref.read(selectedClientsProvider.notifier).state = {c.id};
                          }
                        },
                        onTap: () {
                          if (isSelectionMode) {
                            final currentSet = Set<int>.from(selectedClients);
                            if (isSelected) {
                              currentSet.remove(c.id);
                            } else {
                              currentSet.add(c.id);
                            }
                            ref.read(selectedClientsProvider.notifier).state = currentSet;
                          } else {
                            context.push('/clients/${c.id}');
                          }
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      // --- ❗️ CAMBIO AQUÍ: Reemplazado FAB por SpeedDial ---
      floatingActionButton: SpeedDial(
        icon: Icons.add,
        activeIcon: Icons.close,
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        children: [
          SpeedDialChild(
            child: const Icon(Icons.contact_phone_outlined),
            label: 'Desde Contactos',
            onTap: () => _selectClientFromContacts(context, ref),
          ),
          SpeedDialChild(
            child: const Icon(Icons.person_add_alt_1),
            label: 'Nuevo Manualmente',
            onTap: () => context.push('/clients/new'),
          ),
        ],
      ),
      // --- FIN DE CAMBIO ---
    );
  }
}
