import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasteleria_180_flutter/core/network/validation_exception.dart';
import '../../../core/models/user.dart';
import '../../auth/auth_state.dart';
import '../data/users_repository.dart';

class CreateUserPage extends ConsumerStatefulWidget {
  const CreateUserPage({super.key});

  @override
  ConsumerState<CreateUserPage> createState() => _CreateUserPageState();
}

class _CreateUserPageState extends ConsumerState<CreateUserPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();

  String _role = 'staff';
  bool _loading = false;

  // 🎯 NUEVO: Controla si el texto debe estar oculto
  bool _obscurePass = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  // 🎯 Diálogo de restauración para manejo de error 409
  Future<void> _showRestoreUserDialog(AppUser userToRestore) async {
    if (mounted) setState(() => _loading = false);

    final didConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Usuario Encontrado en Papelera'),
        content: Text(
          'El usuario "${userToRestore.name}" ya existe pero fue eliminado (soft delete). ¿Deseas restaurarlo?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Sí, Restaurar'),
          ),
        ],
      ),
    );

    if (didConfirm != true || !mounted) return;

    setState(() => _loading = true);

    try {
      await ref.read(usersRepoProvider).restoreUser(userToRestore.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Usuario ${userToRestore.name} restaurado con éxito.'),
          backgroundColor: Colors.green[600],
        ),
      );

      ref.invalidate(usersListProvider);
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al restaurar: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);

    try {
      final newUser = await ref
          .read(usersRepoProvider)
          .createUser(
            name: _name.text.trim(),
            email: _email.text.trim(),
            password: _pass.text,
            role: _role,
          );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Usuario "${newUser.name}" creado con éxito.'),
          backgroundColor: Colors.green[600],
        ),
      );

      ref.invalidate(usersListProvider);
      Navigator.of(context).pop();
    } on ValidationException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 5),
        ),
      );
    } on DioException catch (e) {
      if (!mounted) return;

      if (e.response?.statusCode == 409 && e.response?.data?['user'] != null) {
        final userData = e.response?.data?['user'];
        final userToRestore = AppUser.fromJson(
          Map<String, dynamic>.from(userData),
        );
        _showRestoreUserDialog(userToRestore);
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${e.message}'),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error desconocido: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    if (auth.user?.role != 'admin') {
      return const Scaffold(
        body: Center(
          child: Text('Acceso denegado. Solo para administradores.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Crear Nuevo Usuario')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Completa los datos del nuevo miembro del equipo.',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 24),

                      // Nombre
                      TextFormField(
                        controller: _name,
                        enabled: !_loading,
                        decoration: const InputDecoration(
                          labelText: 'Nombre Completo',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Requerido'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      // Email
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

                      // Contraseña
                      TextFormField(
                        controller: _pass,
                        enabled: !_loading,
                        // 🎯 Usar el estado para controlar la visibilidad
                        obscureText: _obscurePass,
                        decoration: InputDecoration(
                          // Quita el `const` para poder usar el IconButton
                          labelText: 'Contraseña (temporal)',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.lock_outline),
                          helperText: 'El usuario podrá cambiarla luego.',
                          // 🎯 NUEVO: Icono de visibilidad (el "ojito")
                          suffixIcon: IconButton(
                            icon: Icon(
                              // Cambia el ícono según el estado de _obscurePass
                              _obscurePass
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            onPressed: () {
                              // Al presionar, cambia el estado y redibuja
                              setState(() {
                                _obscurePass = !_obscurePass;
                              });
                            },
                          ),
                        ),
                        validator: (v) => (v == null || v.length < 8)
                            ? 'Mínimo 8 caracteres'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      // Rol
                      DropdownButtonFormField<String>(
                        initialValue: _role,
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
                      const SizedBox(height: 32),

                      // Botón
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
                                'Crear Usuario',
                                style: TextStyle(fontSize: 16),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
