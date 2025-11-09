// users_trashed_page.dart (NUEVO ARCHIVO)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/user.dart';
import '../data/users_repository.dart';

class UsersTrashedPage extends ConsumerWidget {
  const UsersTrashedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Observar la lista de usuarios eliminados
    final trashedUsersAsync = ref.watch(trashedUsersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Papelera de Usuarios')),
      body: trashedUsersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) =>
            Center(child: Text('Error al cargar papelera: $err')),
        data: (users) {
          if (users.isEmpty) {
            return const Center(child: Text('La papelera está vacía.'));
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(trashedUsersProvider);
            },
            child: ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];

                return ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: Text(user.name),
                  subtitle: Text(user.email),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 1. Botón RESTAURAR
                      IconButton(
                        icon: const Icon(Icons.restore, color: Colors.green),
                        tooltip: 'Restaurar',
                        onPressed: () => _restoreUser(context, ref, user),
                      ),
                      // 2. Botón ELIMINAR PERMANENTEMENTE
                      IconButton(
                        icon: const Icon(Icons.clear, color: Colors.red),
                        tooltip: 'Eliminar permanentemente',
                        onPressed: () => _forceDeleteUser(context, ref, user),
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

  // --- Lógica de Restauración ---
  Future<void> _restoreUser(
    BuildContext context,
    WidgetRef ref,
    AppUser user,
  ) async {
    final bool? confirmed = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Restauración'),
        content: Text('¿Deseas restaurar a ${user.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(usersRepoProvider).restoreUser(user.id);

      // Invalidar ambas listas: Activos y Papelera
      ref.invalidate(usersListProvider);
      ref.invalidate(trashedUsersProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Usuario ${user.name} restaurado.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al restaurar: $e')));
      }
    }
  }

  // --- Lógica de Eliminación Permanente ---
  Future<void> _forceDeleteUser(
    BuildContext context,
    WidgetRef ref,
    AppUser user,
  ) async {
    final bool? confirmed = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ELIMINAR PERMANENTEMENTE'),
        content: Text(
          '¡ADVERTENCIA! ¿Estás seguro de ELIMINAR PERMANENTEMENTE a ${user.name}?\nEsta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(usersRepoProvider).forceDeleteUser(user.id);

      // Solo necesitamos invalidar la Papelera
      ref.invalidate(trashedUsersProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Usuario ${user.name} eliminado permanentemente.'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar permanentemente: $e')),
        );
      }
    }
  }
}
