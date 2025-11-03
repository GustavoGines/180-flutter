import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pasteleria_180_flutter/feature/clients/clients_repository.dart';
import 'package:dio/dio.dart';
import 'package:pasteleria_180_flutter/core/models/client.dart';

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
      // USAMOS EL PROVIDER DEL REPO
      final asyncClient = ref.watch(clientDetailsProvider(clientId!));
      return Scaffold(
        // --- ADAPTADO AL TEMA ---
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
        // --- FIN ADAPTACIÓN ---
        body: asyncClient.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err')),
          data: (client) {
            if (client == null) {
              return const Center(child: Text('Cliente no encontrado.'));
            }
            // Cuando carga, muestra el formulario con los datos
            return _ClientForm(client: client);
          },
        ),
      );
    } else {
      // Modo Creación: Mostrar formulario vacío
      return Scaffold(
        // --- ADAPTADO AL TEMA ---
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
        // --- FIN ADAPTACIÓN ---
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
  final _notesController = TextEditingController(); // AÑADIDO PARA NOTAS
  bool _isLoading = false;

  bool get isEditMode => widget.client != null;

  @override
  void initState() {
    super.initState();
    // Si estamos editando, llenar los campos
    if (isEditMode) {
      _nameController.text = widget.client!.name;
      _phoneController.text = widget.client!.phone ?? '';
      _emailController.text = widget.client!.email ?? '';
      _notesController.text = widget.client!.notes ?? ''; // AÑADIDO
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _notesController.dispose(); // AÑADIDO
    super.dispose();
  }

  // --- Helper de SnackBar adaptado al tema ---
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
  // --- Fin Helper ---

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return; // Validación falló
    }

    setState(() => _isLoading = true);

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
          : _notesController.text.trim(), // AÑADIDO
    };

    try {
      final repo = ref.read(clientsRepoProvider);
      String successMessage;

      if (isEditMode) {
        // --- Lógica de Actualización ---
        await repo.updateClient(widget.client!.id, payload);
        successMessage = 'Cliente actualizado con éxito';
        // Invalidar el caché del cliente editado
        ref.invalidate(clientDetailsProvider(widget.client!.id));
      } else {
        // --- Lógica de Creación ---
        await repo.createClient(payload);
        successMessage = 'Cliente creado con éxito';
      }

      // Invalidar la lista de búsqueda para que se refresque
      ref.invalidate(clientsListProvider);

      if (mounted) {
        // --- USA EL HELPER ADAPTADO ---
        _showSnackbar(successMessage);
        context.pop(); // Volver a la página anterior
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Error: ${e.toString()}';

        // ¡AQUÍ ESTÁ LA LÓGICA DE RESTAURACIÓN!
        if (e is DioException && e.response?.statusCode == 409) {
          try {
            // Laravel nos envió el cliente en el cuerpo del error
            final clientData = e.response?.data['client'];
            final clientToRestore = Client.fromJson(
              (clientData as Map).map((k, v) => MapEntry(k.toString(), v)),
            );

            // Oculta el loader y muestra el diálogo de restauración
            setState(() => _isLoading = false);
            _showRestoreDialog(clientToRestore);
            return; // Sal del catch, ya estamos manejando esto
          } catch (parseError) {
            errorMessage =
                'Se encontró un cliente eliminado, pero no se pudo leer.';
          }
        }
        // Si no fue un 409, muestra el error normal
        setState(() => _isLoading = false);
        // --- USA EL HELPER ADAPTADO ---
        _showSnackbar(errorMessage, isError: true);
      }
    } finally {
      if (mounted) {
        // Asegurarse de que el loading se quite si no fue el caso 409
        if (_isLoading) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _handleDelete() async {
    // Obtenemos el ColorScheme ANTES del diálogo
    final cs = Theme.of(context).colorScheme;

    // 1. Pedir confirmación
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
            // --- ADAPTADO AL TEMA ---
            style: FilledButton.styleFrom(
              backgroundColor: cs.error,
              foregroundColor: cs.onError,
            ),
            // --- FIN ADAPTACIÓN ---
            child: const Text('Sí, Enviar a Papelera'),
          ),
        ],
      ),
    );

    if (didConfirm != true) return; // Si el usuario cancela, no hagas nada

    // 2. Si confirma, proceder a eliminar (soft delete)
    setState(() => _isLoading = true);

    try {
      await ref.read(clientsRepoProvider).deleteClient(widget.client!.id);

      // 3. Invalidar los providers para refrescar las listas
      ref.invalidate(clientsListProvider); // Invalida la lista principal
      ref.invalidate(trashedClientsProvider); // Invalida la papelera
      ref.invalidate(
        clientDetailsProvider(widget.client!.id),
      ); // Invalida este cliente

      if (mounted) {
        // --- USA EL HELPER ADAPTADO ---
        _showSnackbar('Cliente enviado a la papelera');
        // Salir de la página de edición
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        // --- USA EL HELPER ADAPTADO ---
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
            // Este botón usa el estilo 'primary' por defecto, lo cual es correcto.
            child: const Text('Sí, Restaurar'),
          ),
        ],
      ),
    );

    if (didConfirm != true) return;

    // Si confirma, llama al repositorio para restaurar
    setState(() => _isLoading = true);
    try {
      await ref.read(clientsRepoProvider).restoreClient(clientToRestore.id);

      // Invalidar listas para que se refresquen
      ref.invalidate(clientsListProvider);
      ref.invalidate(trashedClientsProvider); // <-- USAR NOMBRE CORRECTO

      if (mounted) {
        // --- USA EL HELPER ADAPTADO ---
        _showSnackbar('Cliente restaurado con éxito');
        context.pop(); // Cierra la página de creación
      }
    } catch (e) {
      if (mounted) {
        // --- USA EL HELPER ADAPTADO ---
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
    // --- OBTENER COLORES DEL TEMA ---
    final cs = Theme.of(context).colorScheme;

    // --- ESTILOS ADAPTADOS AL TEMA ---
    final inputStyle = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12.0),
      borderSide: BorderSide(color: cs.outline), // Usa color de borde del tema
    );
    final focusedStyle = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12.0),
      borderSide: BorderSide(
        color: cs.primary,
        width: 2.0,
      ), // Usa color primario
    );
    // --- FIN ESTILOS ADAPTADOS ---

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
              // --- ADAPTADO AL TEMA ---
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
              // --- ADAPTADO AL TEMA ---
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
              // --- ADAPTADO AL TEMA ---
              prefixIcon: Icon(Icons.email, color: cs.primary),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          // CAMPO DE NOTAS AÑADIDO
          TextFormField(
            controller: _notesController,
            decoration: InputDecoration(
              labelText: 'Notas Adicionales',
              border: inputStyle,
              focusedBorder: focusedStyle,
              // --- ADAPTADO AL TEMA ---
              prefixIcon: Icon(Icons.note_alt, color: cs.primary),
            ),
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _isLoading ? null : _submit,
            icon: _isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      // --- ADAPTADO AL TEMA ---
                      color: cs.onPrimary, // Contraste con el botón
                    ),
                  )
                : const Icon(Icons.save),
            label: Text(isEditMode ? 'Guardar Cambios' : 'Crear Cliente'),
            // --- ADAPTADO AL TEMA ---
            style: FilledButton.styleFrom(
              // Se eliminan backgroundColor y foregroundColor
              // para usar los defaults del tema (primary/onPrimary)
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            // --- FIN ADAPTACIÓN ---
          ),
          if (isEditMode) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _handleDelete,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Enviar a Papelera'),
              // --- ADAPTADO AL TEMA ---
              style: OutlinedButton.styleFrom(
                foregroundColor: cs.error, // Texto y borde de error
                side: BorderSide(color: cs.error),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              // --- FIN ADAPTACIÓN ---
            ),
          ],
        ],
      ),
    );
  }
}
