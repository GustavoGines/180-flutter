import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pasteleria_180_flutter/feature/auth/auth_repository.dart';

class ResetPasswordPage extends ConsumerStatefulWidget {
  final String token;
  final String email;

  const ResetPasswordPage({
    super.key,
    required this.token,
    required this.email,
  });

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  final _passwordController = TextEditingController();
  final _passwordConfirmationController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // <-- 1. AÑADE LAS VARIABLES DE ESTADO PARA LOS OJOS
  bool _passwordVisible = false;
  bool _passwordConfirmationVisible = false;

  // Paleta de colores de la app
  static const Color primaryPink = Color(0xFFF9C0C0);
  static const Color darkBrown = Color(0xFF7A4A4A);
  static const Color lightBrownText = Color(0xFFA57D7D);

  @override
  void initState() {
    super.initState();
    // <-- 2. INICIALÍZALAS (OPCIONAL PERO RECOMENDADO)
    _passwordVisible = false;
    _passwordConfirmationVisible = false;
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _passwordConfirmationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Validar que los campos no estén vacíos y coincidan
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    // Llama al método resetPassword que deberías tener en tu AuthRepository
    final success = await ref
        .read(authRepoProvider)
        .resetPassword(
          token: widget.token,
          email: widget.email,
          password: _passwordController.text,
          passwordConfirmation: _passwordConfirmationController.text,
        );

    if (mounted) {
      setState(() => _isLoading = false);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Tu contraseña ha sido restablecida con éxito!'),
            backgroundColor: Colors.green,
          ),
        );
        // Navega a la pantalla de login. Usamos go para limpiar el historial de rutas.
        context.go('/login');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'El enlace ha expirado o es inválido. Inténtalo de nuevo.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Establecer Contraseña',
          style: TextStyle(color: darkBrown),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: darkBrown),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              // Texto de instrucción
              const Text(
                'Ingresa tu nueva contraseña. Debe tener al menos 8 caracteres.',
                textAlign: TextAlign.center,
                style: TextStyle(color: lightBrownText, fontSize: 16),
              ),
              const SizedBox(height: 32),

              // Campo de Nueva Contraseña
              TextFormField(
                controller: _passwordController,
                obscureText: !_passwordVisible, // <-- 3. USA LA VARIABLE
                decoration: _buildInputDecoration('Nueva Contraseña').copyWith(
                  // <-- 4. USA .copyWith()
                  // --- AÑADE EL ICONO SUFIJO ---
                  suffixIcon: IconButton(
                    icon: Icon(
                      _passwordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: lightBrownText,
                    ),
                    onPressed: () {
                      setState(() {
                        _passwordVisible = !_passwordVisible;
                      });
                    },
                  ),
                ),
                style: const TextStyle(color: darkBrown),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, ingresa una contraseña.';
                  }
                  if (value.length < 8) {
                    return 'La contraseña debe tener al menos 8 caracteres.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Campo de Confirmar Contraseña
              TextFormField(
                controller: _passwordConfirmationController,
                obscureText:
                    !_passwordConfirmationVisible, // <-- 3. USA LA OTRA VARIABLE
                decoration: _buildInputDecoration('Confirmar Contraseña')
                    .copyWith(
                      // <-- 4. USA .copyWith()
                      // --- AÑADE EL OTRO ICONO SUFIJO ---
                      suffixIcon: IconButton(
                        icon: Icon(
                          _passwordConfirmationVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: lightBrownText,
                        ),
                        onPressed: () {
                          setState(() {
                            _passwordConfirmationVisible =
                                !_passwordConfirmationVisible;
                          });
                        },
                      ),
                    ),
                style: const TextStyle(color: darkBrown),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, confirma tu contraseña.';
                  }
                  if (value != _passwordController.text) {
                    return 'Las contraseñas no coinciden.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // Botón de Cambiar Contraseña
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: _isLoading ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: darkBrown,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        )
                      : const Text(
                          'Cambiar Contraseña',
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper para no repetir la decoración de los TextFields
  InputDecoration _buildInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: lightBrownText),
      filled: true,
      fillColor: primaryPink.withAlpha(26),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: darkBrown, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryPink.withAlpha(77)),
      ),
    );
  }
}
