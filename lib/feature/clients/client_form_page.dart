// Archivo: lib/feature/clients/client_form_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'clients_repository.dart';
import 'package:dio/dio.dart'; // 👈 AÑADE ESTO
import '../../core/models/client.dart'; // 👈 Asegúrate que esté


// Provider para buscar el cliente por ID (solo para modo edición)
final clientByIdProvider = FutureProvider.autoDispose.family<Client?, int>((
  ref,
  id,
) {
  return ref.watch(clientsRepoProvider).getClientById(id);
});

class ClientFormPage extends ConsumerWidget {
  final int? clientId; // Si es null, es "Crear". Si tiene ID, es "Editar".
  const ClientFormPage({super.key, this.clientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isEditMode = clientId != null;

    if (isEditMode) {
      // Modo Edición: Cargar datos primero
      final asyncClient = ref.watch(clientByIdProvider(clientId!));
      return Scaffold(
        appBar: AppBar(title: const Text('Editar Cliente')),
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
        appBar: AppBar(title: const Text('Nuevo Cliente')),
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
  final _addressController = TextEditingController();
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
      //_addressController.text = widget.client!.address ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

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
      'address': _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim(),
    };

    try {
      final repo = ref.read(clientsRepoProvider);
      String successMessage;

      if (isEditMode) {
        // --- Lógica de Actualización ---
        await repo.updateClient(widget.client!.id, payload);
        successMessage = 'Cliente actualizado con éxito';
        // Invalidar el caché del cliente editado
        ref.invalidate(clientByIdProvider(widget.client!.id));
      } else {
        // --- Lógica de Creación ---
        await repo.createClient(payload);
        successMessage = 'Cliente creado con éxito';
      }

      // Invalidar la lista de búsqueda para que se refresque
      ref.invalidate(clientsRepoProvider); // Esto es simple pero ineficiente.
      // Sería mejor tener un provider de "searchQuery" y ref.invalidate(searchClientsProvider)

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: Colors.green,
          ),
        );
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
              (clientData as Map).map((k, v) => MapEntry(k.toString(), v))
            );
            
            // Oculta el loader y muestra el diálogo de restauración
            setState(() => _isLoading = false);
            _showRestoreDialog(clientToRestore);
            return; // Sal del catch, ya estamos manejando esto
            
          } catch (parseError) {
             errorMessage = 'Se encontró un cliente eliminado, pero no se pudo leer.';
          }
        }
        // Si no fue un 409, muestra el error normal
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleDelete() async {
    // 1. Pedir confirmación
    final didConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: Text(
          '¿Estás seguro de que quieres eliminar a ${widget.client!.name}? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (didConfirm != true) return; // Si el usuario cancela, no hagas nada

    // 2. Si confirma, proceder a eliminar
    setState(() => _isLoading = true);

    try {
      await ref.read(clientsRepoProvider).deleteClient(widget.client!.id);

      // 3. Invalidar los providers para refrescar las listas
      ref.invalidate(clientsRepoProvider); // Invalida toda la búsqueda/lista
      ref.invalidate(
        clientByIdProvider(widget.client!.id),
      ); // Invalida este cliente

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cliente eliminado'),
            backgroundColor: Colors.green,
          ),
        );
        // Salir de la página de edición, ya que el cliente no existe
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // 👇 AÑADE ESTA NUEVA FUNCIÓN
  Future<void> _showRestoreDialog(Client clientToRestore) async {
    final didConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cliente Encontrado'),
        content: Text(
            'El cliente "${clientToRestore.name}" ya existe pero fue eliminado. ¿Deseas restaurarlo?'),
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

    // Si confirma, llama al repositorio para restaurar
    setState(() => _isLoading = true);
    try {
      await ref.read(clientsRepoProvider).restoreClient(clientToRestore.id);
      
      // Invalidar listas para que se refresquen
      ref.invalidate(clientsRepoProvider);
      ref.invalidate(getTrashedClientsProvider); // (Provider que crearemos abajo)

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cliente restaurado con éxito'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop(); // Cierra la página de creación
      }
    } catch (e) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al restaurar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }

  }
  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nombre Completo *',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
            validator: (value) => (value == null || value.trim().isEmpty)
                ? 'El nombre es obligatorio'
                : null,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: 'Teléfono',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.phone),
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.email),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _addressController,
            decoration: const InputDecoration(
              labelText: 'Dirección',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.location_on),
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _isLoading ? null : _submit,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: Text(isEditMode ? 'Guardar Cambios' : 'Crear Cliente'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          if (isEditMode) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _handleDelete,
              icon: const Icon(Icons.delete_forever),
              label: const Text('Eliminar Cliente'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade700,
                side: BorderSide(color: Colors.red.shade300),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
