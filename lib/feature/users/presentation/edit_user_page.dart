import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/user.dart';
import '../data/users_repository.dart';

/// Pantalla "wrapper" que maneja la carga del usuario por ID
class EditUserPage extends ConsumerWidget {
  final int userId;
  const EditUserPage({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Usamos el provider de detalles que creamos en el repositorio
    final userAsync = ref.watch(userDetailsProvider(userId));

    return Scaffold(
      appBar: AppBar(title: const Text('Editar Usuario')),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) =>
            Center(child: Text('Error al cargar usuario: $err')),
        // Cuando tenemos los datos, mostramos el formulario
        data: (user) => _EditUserForm(user: user),
      ),
    );
  }
}

/// Widget interno que contiene el formulario (Stateful)
class _EditUserForm extends ConsumerStatefulWidget {
  final AppUser user;
  const _EditUserForm({required this.user});

  @override
  ConsumerState<_EditUserForm> createState() => _EditUserFormState();
}

class _EditUserFormState extends ConsumerState<_EditUserForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _name;
  late TextEditingController _email;
  late String _role;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // Inicializamos los controllers con los datos del usuario
    _name = TextEditingController(text: widget.user.name);
    _email = TextEditingController(text: widget.user.email);
    _role = widget.user.role;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _loading = true);

    // Creamos el payload solo con los campos que queremos actualizar
    final payload = {
      'name': _name.text.trim(),
      'email': _email.text.trim(),
      'role': _role,
    };

    try {
      final updatedUser = await ref
          .read(usersRepoProvider)
          .updateUser(widget.user.id, payload);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Usuario "${updatedUser.name}" actualizado.'),
          backgroundColor: Colors.green[600],
        ),
      );

      // Invalidamos los providers para refrescar los datos en todos lados
      ref.invalidate(usersListProvider);
      ref.invalidate(userDetailsProvider(widget.user.id));

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al actualizar: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Editando a ${widget.user.name}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),

              // --- Campo Nombre ---
              TextFormField(
                controller: _name,
                enabled: !_loading,
                decoration: const InputDecoration(
                  labelText: 'Nombre Completo',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),

              // --- Campo Email ---
              TextFormField(
                controller: _email,
                enabled: !_loading,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Requerido';
                  if (!v.contains('@') || !v.contains('.')) {
                    return 'Email no válido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // --- Campo Rol ---
              DropdownButtonFormField<String>(
                initialValue: _role,
                // The named parameter 'enabled' isn't defined.
                decoration: const InputDecoration(
                  labelText: 'Rol de Usuario',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.shield_outlined),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'staff',
                    child: Text('Staff (Empleado)'),
                  ),
                  DropdownMenuItem(
                    value: 'admin',
                    child: Text('Admin (Administrador)'),
                  ),
                ],
                onChanged: (v) => setState(() => _role = v ?? 'staff'),
              ),
              const SizedBox(height: 16),
              Text(
                'La contraseña solo puede ser cambiada por el propio usuario o mediante "Olvidé mi contraseña".',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 32),

              // --- Botón de Enviar ---
              FilledButton(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Guardar Cambios',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
