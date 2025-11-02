import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/models/user.dart';
import '../../auth/auth_state.dart';
import '../data/users_repository.dart';
import 'create_user_page.dart'; // Para navegar a la pág de creación
import 'edit_user_page.dart'; // Para navegar a la pág de edición

// Provider para manejar el texto de búsqueda
final userSearchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

class UsersListPage extends ConsumerStatefulWidget {
  const UsersListPage({super.key});

  @override
  ConsumerState<UsersListPage> createState() => _UsersListPageState();
}

class _UsersListPageState extends ConsumerState<UsersListPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- Lógica para eliminar un usuario ---
  Future<void> _deleteUser(AppUser user) async {
    // 1. Mostrar diálogo de confirmación
    final bool? confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: Text(
          '¿Estás seguro de que deseas eliminar a ${user.name}?\nEsta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    // 2. Si no confirma, no hacer nada
    if (confirmed != true) return;

    try {
      // 3. Llamar al repositorio
      await ref.read(usersRepoProvider).deleteUser(user.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Usuario ${user.name} eliminado.'),
          backgroundColor: Colors.green[600],
        ),
      );

      // 4. Invalidar el provider de la lista para que se recargue
      ref.invalidate(usersListProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al eliminar: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- Verificación de Admin ---
    final auth = ref.watch(authStateProvider);
    if (auth.user?.role != 'admin') {
      return const Scaffold(
        body: Center(
          child: Text('Acceso denegado. Solo para administradores.'),
        ),
      );
    }

    // --- Provider de Búsqueda ---
    // Observamos el query. El .family del repository se encargará de buscar
    final searchQuery = ref.watch(userSearchQueryProvider);
    final usersAsync = ref.watch(usersListProvider(searchQuery));

    return Scaffold(
      appBar: AppBar(title: const Text('Gestionar Usuarios')),
      // --- Botón para Crear Usuario ---
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const CreateUserPage()));
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // --- Barra de Búsqueda ---
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Buscar por nombre o email...',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(userSearchQueryProvider.notifier).state = '';
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                // Actualizamos el provider de búsqueda
                ref.read(userSearchQueryProvider.notifier).state = value;
              },
            ),
          ),

          // --- Lista de Usuarios ---
          Expanded(
            child: usersAsync.when(
              // --- Estado: Cargando ---
              loading: () => const Center(child: CircularProgressIndicator()),

              // --- Estado: Error ---
              error: (err, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('Error al cargar usuarios: $err'),
                ),
              ),

              // --- Estado: Datos Cargados ---
              data: (users) {
                if (users.isEmpty) {
                  return Center(
                    child: Text(
                      searchQuery.isEmpty
                          ? 'No hay usuarios registrados.'
                          : 'No se encontraron usuarios para "$searchQuery".',
                    ),
                  );
                }

                // --- ListView ---
                return RefreshIndicator(
                  onRefresh: () async {
                    // Invalidamos el provider para forzar la recarga
                    ref.invalidate(usersListProvider);
                  },
                  child: ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];

                      // --- Item de la Lista ---
                      return ListTile(
                        leading: CircleAvatar(
                          child: Icon(
                            user.isAdmin
                                ? Icons.admin_panel_settings
                                : Icons.person_outline,
                          ),
                        ),
                        title: Text(user.name),
                        subtitle: Text(user.email),
                        // --- Chip de Rol ---
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Chip(
                              label: Text(
                                user.role == 'admin' ? 'Admin' : 'Staff',
                                style: TextStyle(
                                  color: user.isAdmin
                                      ? Colors.red
                                      : Colors.blue,
                                ),
                              ),
                              backgroundColor: user.isAdmin
                                  ? Colors.red.shade100
                                  : Colors.blue.shade100,
                            ),
                            // --- Botón Editar ---
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        EditUserPage(userId: user.id),
                                  ),
                                );
                              },
                            ),
                            // --- Botón Eliminar ---
                            IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                color: Theme.of(context).colorScheme.error,
                              ),
                              onPressed: () => _deleteUser(user),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
