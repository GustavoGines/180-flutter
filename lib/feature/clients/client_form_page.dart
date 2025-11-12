// client_form_page.dart (CON CAMBIOS)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pasteleria_180_flutter/feature/clients/clients_repository.dart';
import 'package:dio/dio.dart';
import 'package:pasteleria_180_flutter/core/models/client.dart';
// --- IMPORTAMOS EL DIÁLOGO DE DIRECCIÓN ---
import 'package:pasteleria_180_flutter/feature/clients/address_form_dialog.dart';

class ClientFormPage extends ConsumerWidget {
  final int? clientId; // Si es null, es "Crear". Si tiene ID, es "Editar".
  const ClientFormPage({super.key, this.clientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isEditMode = clientId != null;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (isEditMode) {
      // Modo Edición: Cargar datos primero
      final asyncClient = ref.watch(clientDetailsProvider(clientId!));
      return Scaffold(
        appBar: AppBar(
          title: const Text('Editar Cliente'),
          backgroundColor: cs.surface,
          foregroundColor: cs.onSurface,
          elevation: 1,
          titleTextStyle: tt.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: cs.onSurface,
          ),
        ),
        body: asyncClient.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err')),
          data: (client) {
            if (client == null) {
              return const Center(child: Text('Cliente no encontrado.'));
            }
            return _ClientForm(client: client);
          },
        ),
      );
    } else {
      // Modo Creación: Mostrar formulario vacío
      return Scaffold(
        appBar: AppBar(
          title: const Text('Nuevo Cliente'),
          backgroundColor: cs.surface,
          foregroundColor: cs.onSurface,
          elevation: 1,
          titleTextStyle: tt.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: cs.onSurface,
          ),
        ),
        body: const _ClientForm(), // Pasa null
      );
    }
  }
}

// Widget interno con el estado del formulario
class _ClientForm extends ConsumerStatefulWidget {
  final Client? client; // El cliente existente (si estamos editando)
  const _ClientForm({this.client});

  @override
  ConsumerState<_ClientForm> createState() => _ClientFormState();
}

class _ClientFormState extends ConsumerState<_ClientForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isLoading = false;

  // --- ❗️ NUEVOS ESTADOS ---
  bool _addAddressOnSave = false;
  Client? _clientJustCreated; // Para guardar el cliente recién creado
  // --- FIN NUEVOS ESTADOS ---

  bool get isEditMode => widget.client != null;

  @override
  void initState() {
    super.initState();
    if (isEditMode) {
      _nameController.text = widget.client!.name;
      _phoneController.text = widget.client!.phone ?? '';
      _emailController.text = widget.client!.email ?? '';
      _notesController.text = widget.client!.notes ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
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

  // --- ❗️ FUNCIÓN _submit MODIFICADA ---
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return; // Validación falló
    }

    setState(() => _isLoading = true);
    _clientJustCreated = null; // Reseteamos por si acaso

    final payload = {
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      'email': _emailController.text.trim().isEmpty
          ? null
          : _emailController.text.trim(),
      'notes': _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    };

    try {
      final repo = ref.read(clientsRepoProvider);
      String successMessage;

      if (isEditMode) {
        // --- Lógica de Actualización ---
        await repo.updateClient(widget.client!.id, payload);
        successMessage = 'Cliente actualizado con éxito';
        ref.invalidate(clientDetailsProvider(widget.client!.id));
      } else {
        // --- Lógica de Creación ---
        // 1. Guardamos el cliente recién creado
        _clientJustCreated = await repo.createClient(payload);
        successMessage = 'Cliente creado con éxito';
      }

      // Invalidar la lista de búsqueda para que se refresque
      ref.invalidate(clientsListProvider);

      if (mounted) {
        // 2. Si NO estamos en modo edición Y SÍ se marcó el checkbox...
        if (!isEditMode && _addAddressOnSave) {
          // No hacemos pop y no mostramos snackbar aquí.
          // _clientJustCreated ya está asignado.
        } else {
          // Si es modo edición o no se quiso añadir dirección:
          _showSnackbar(successMessage);
          context.pop(); // Volver a la página anterior
        }
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Error: ${e.toString()}';
        _clientJustCreated = null; // Anulamos la creación si hay error

        if (e is DioException && e.response?.statusCode == 409) {
          try {
            final clientData = e.response?.data['client'];
            final clientToRestore = Client.fromJson(
              (clientData as Map).map((k, v) => MapEntry(k.toString(), v)),
            );
            setState(() => _isLoading = false);
            _showRestoreDialog(clientToRestore);
            return;
          } catch (parseError) {
            errorMessage =
                'Se encontró un cliente eliminado, pero no se pudo leer.';
          }
        }
        _showSnackbar(errorMessage, isError: true);
      }
    } finally {
      // 3. El loader se quita en CUALQUIER caso (éxito, error, o paso-al-modal)
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }

    // --- 4. ACCIÓN POST-GUARDADO ---
    // Si el cliente se creó Y se marcó el checkbox
    if (!isEditMode && _clientJustCreated != null && _addAddressOnSave) {
      if (!mounted) return;

      // 5. Mostramos el modal de dirección (reutilizado)
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          // Le pasamos el ID del cliente recién creado
          child: AddressFormDialog(clientId: _clientJustCreated!.id),
        ),
      );

      // 6. Cuando el modal se cierra (por guardar o cancelar),
      // cerramos la página de creación de cliente.
      if (mounted) {
        context.pop();
      }
    }
  }
  // --- FIN DE _submit MODIFICADA ---

  Future<void> _handleDelete() async {
    final cs = Theme.of(context).colorScheme;
    final didConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Envío a Papelera'),
        content: Text(
          '¿Estás seguro de que quieres enviar a ${widget.client!.name} a la papelera?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: cs.error,
              foregroundColor: cs.onError,
            ),
            child: const Text('Sí, Enviar a Papelera'),
          ),
        ],
      ),
    );

    if (didConfirm != true) return;
    setState(() => _isLoading = true);

    try {
      await ref.read(clientsRepoProvider).deleteClient(widget.client!.id);
      ref.invalidate(clientsListProvider);
      ref.invalidate(trashedClientsProvider);
      ref.invalidate(clientDetailsProvider(widget.client!.id));

      if (mounted) {
        _showSnackbar('Cliente enviado a la papelera');
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar('Error al eliminar: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showRestoreDialog(Client clientToRestore) async {
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

    if (didConfirm != true) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(clientsRepoProvider).restoreClient(clientToRestore.id);
      ref.invalidate(clientsListProvider);
      ref.invalidate(trashedClientsProvider);

      if (mounted) {
        _showSnackbar('Cliente restaurado con éxito');
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar('Error al restaurar: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final inputStyle = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12.0),
      borderSide: BorderSide(color: cs.outline),
    );
    final focusedStyle = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12.0),
      borderSide: BorderSide(color: cs.primary, width: 2.0),
    );

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Nombre Completo *',
              border: inputStyle,
              focusedBorder: focusedStyle,
              prefixIcon: Icon(Icons.person, color: cs.primary),
            ),
            validator: (value) => (value == null || value.trim().isEmpty)
                ? 'El nombre es obligatorio'
                : null,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phoneController,
            decoration: InputDecoration(
              labelText: 'Teléfono',
              border: inputStyle,
              focusedBorder: focusedStyle,
              prefixIcon: Icon(Icons.phone, color: cs.primary),
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: 'Email',
              border: inputStyle,
              focusedBorder: focusedStyle,
              prefixIcon: Icon(Icons.email, color: cs.primary),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _notesController,
            decoration: InputDecoration(
              labelText: 'Notas Adicionales',
              border: inputStyle,
              focusedBorder: focusedStyle,
              prefixIcon: Icon(Icons.note_alt, color: cs.primary),
            ),
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
          ),

          // --- ❗️ CAMBIO AQUÍ: CHECKBOX CONDICIONAL ---
          if (!isEditMode) ...[
            const SizedBox(height: 16),
            const Divider(),
            CheckboxListTile(
              title: const Text("Añadir dirección principal al guardar"),
              subtitle: const Text(
                "Se abrirá el formulario de dirección después de crear.",
              ),
              value: _addAddressOnSave,
              onChanged: (value) {
                setState(() {
                  _addAddressOnSave = value ?? false;
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              activeColor: cs.primary,
            ),
            const Divider(),
          ],

          // --- FIN DE CAMBIO ---
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _isLoading ? null : _submit,
            icon: _isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: cs.onPrimary,
                    ),
                  )
                : const Icon(Icons.save),
            label: Text(isEditMode ? 'Guardar Cambios' : 'Crear Cliente'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          if (isEditMode) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _handleDelete,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Enviar a Papelera'),
              style: OutlinedButton.styleFrom(
                foregroundColor: cs.error,
                side: BorderSide(color: cs.error),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
