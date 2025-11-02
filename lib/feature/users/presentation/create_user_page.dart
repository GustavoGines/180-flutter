import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Asumimos que auth_state.dart está en lib/features/auth/
// (Ajusta la ruta si es necesario)
import '../../auth/auth_state.dart';
// Ruta actualizada según la nueva estructura
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
  String _role = 'staff'; // Valor por defecto
  bool _loading = false;
  // bool _obscurePass = true; // Opcional: para un botón de ver/ocultar pass

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // 1. Validar el formulario
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _loading = true);

    try {
      // 2. Llamar al repositorio para crear el usuario
      final newUser = await ref
          .read(usersRepoProvider)
          .createUser(
            name: _name.text.trim(),
            email: _email.text.trim(),
            password: _pass.text,
            role: _role,
          );

      // 3. Verificar si el widget sigue "montado" antes de actualizar UI
      if (!mounted) return;

      // 4. Mostrar feedback de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Usuario "${newUser.name}" creado con éxito.'),
          backgroundColor: Colors.green[600],
        ),
      );

      // 5. ¡Clave! Invalidar el provider de la lista
      // Esto fuerza a que la pantalla que muestra la lista se actualice
      ref.invalidate(usersListProvider);

      // 6. Cerrar esta pantalla
      Navigator.of(context).pop();
    } catch (e) {
      // 7. Manejar error
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al crear usuario: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      // 8. Detener el loading (solo si sigue montado)
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- Verificación de Admin ---
    // (Usamos 'watch' para que reaccione si el auth cambia)
    final auth = ref.watch(authStateProvider);
    if (auth.user?.role != 'admin') {
      return const Scaffold(
        body: Center(
          child: Text('Acceso denegado. Solo para administradores.'),
        ),
      );
    }
    // --- Fin Verificación ---

    return Scaffold(
      appBar: AppBar(title: const Text('Crear Nuevo Usuario')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Usamos SingleChildScrollView para evitar overflow del teclado
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.all(20.0), // Más padding
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

                      // --- Campo Nombre ---
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

                      // --- Campo Contraseña ---
                      TextFormField(
                        controller: _pass,
                        enabled: !_loading,
                        obscureText: true, // Ocultar contraseña
                        decoration: const InputDecoration(
                          labelText: 'Contraseña (temporal)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.lock_outline),
                          helperText: 'El usuario podrá cambiarla luego.',
                        ),
                        validator: (v) => (v == null || v.length < 8)
                            ? 'Mínimo 8 caracteres'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      // --- Campo Rol ---
                      DropdownButtonFormField<String>(
                        initialValue: _role,
                        // enabled: !_loading, // 'enabled' no es un parámetro de DropdownButtonFormField
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

                      const SizedBox(height: 32), // Más espacio antes del botón
                      // --- Botón de Enviar ---
                      FilledButton(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        // Deshabilitar el botón si está cargando
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
