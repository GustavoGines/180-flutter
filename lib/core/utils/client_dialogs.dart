import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasteleria_180_flutter/core/models/client.dart';
import 'package:pasteleria_180_flutter/feature/clients/clients_page.dart';
import 'package:pasteleria_180_flutter/feature/clients/clients_repository.dart';
import 'package:pasteleria_180_flutter/core/utils/snackbar_helper.dart';

class ClientDialogs {
  static Future<bool> showRestoreDialog(
    BuildContext context,
    WidgetRef ref,
    Client clientToRestore,
  ) async {
    final didConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cliente Encontrado'),
        content: Text(
          'El cliente "${clientToRestore.name}" ya existe pero fue eliminado. ¿Deseas restaurarlo?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sí, Restaurar'),
          ),
        ],
      ),
    );

    if (didConfirm != true) return false;

    try {
      await ref.read(clientsRepoProvider).restoreClient(clientToRestore.id);
      final currentQuery = ref.read(clientSearchQueryProvider);
      ref.invalidate(clientsListProvider(currentQuery));
      if (currentQuery.isNotEmpty) {
        ref.invalidate(clientsListProvider(''));
      }
      ref.invalidate(trashedClientsProvider);

      if (context.mounted) {
        context.showCustomSnackbar('Cliente restaurado con éxito');
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        context.showCustomSnackbar('Error al restaurar: $e', isError: true);
      }
      return false;
    }
  }
}
