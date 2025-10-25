import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'auth_repository.dart'; // Asegúrate de que esta ruta sea correcta
import 'auth_state.dart'; // Asegúrate de que esta ruta sea correcta

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});
  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _passwordVisible = false; // <-- 1. AÑADE LA VARIABLE DE ESTADO

  // Definir los colores basados en tu logo
  static const Color primaryPink = Color(0xFFF9C0C0); // Rosa claro del logo
  static const Color darkBrown = Color(0xFF7A4A4A); // Marrón del rodillo
  static const Color lightBrownText = Color(
    0xFFA57D7D,
  ); // Un marrón más claro para texto secundario

  @override
  void initState() {
    super.initState();
    ref.read(authRepoProvider).init();
    _passwordVisible =
        false; // <-- 2. INICIALIZA (OPCIONAL PERO BUENA PRÁCTICA)
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ok = await ref
          .read(authRepoProvider)
          .login(email: _email.text.trim(), password: _password.text);
      if (ok) {
        final user = await ref.read(authRepoProvider).me();
        ref.read(authStateProvider.notifier).setUser(user);
        if (mounted) context.go('/');
      } else {
        setState(() => _error = 'Credenciales inválidas');
      }
    } catch (e) {
      setState(() => _error = 'Error de conexión o credenciales incorrectas');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: 24.0,
          vertical: 10.0,
        ), // Mayor padding vertical superior
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start, // Alinea desde el inicio
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // --- LOGO ---
            Image.asset(
              'assets/images/logo_180.png', // Asegúrate de que esta sea la ruta correcta de tu logo
              height: 350, // Un poco más pequeño para un look más refinado
              fit: BoxFit.contain,
            ),
            const SizedBox(
              height: 5,
            ), // Espacio un poco menor para acercar el logo al formulario
            // --- TÍTULO (Opcional, para dar contexto) ---
            Text(
              'Bienvenido a 180° Pastelería',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: darkBrown,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32), // Espacio entre título y campos
            // --- CAMPO EMAIL ---
            TextField(
              controller: _email,
              decoration: InputDecoration(
                labelText: 'Email',
                labelStyle: TextStyle(color: lightBrownText),
                filled: true,
                fillColor: primaryPink.withAlpha(26),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide
                      .none, // Borde más sutil o sin borde en estado normal
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: darkBrown, width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: primaryPink.withAlpha(77),
                  ), // Borde más claro
                ),
              ),
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: darkBrown),
            ),
            const SizedBox(height: 16),

            // --- CAMPO CONTRASEÑA ---
            TextField(
              controller: _password,
              obscureText:
                  !_passwordVisible, // <-- 3. USA LA VARIABLE DE ESTADO
              decoration: InputDecoration(
                labelText: 'Contraseña',
                labelStyle: TextStyle(color: lightBrownText),
                filled: true,
                fillColor: primaryPink.withAlpha(26),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none, // Borde más sutil
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: darkBrown, width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: primaryPink.withAlpha(77)),
                ),
                // --- 4. AÑADE EL ICONO SUFIJO ---
                suffixIcon: IconButton(
                  icon: Icon(
                    // Elige el icono basado en el estado
                    _passwordVisible ? Icons.visibility : Icons.visibility_off,
                    color: lightBrownText,
                  ),
                  onPressed: () {
                    // Actualiza el estado al ser presionado
                    setState(() {
                      _passwordVisible = !_passwordVisible;
                    });
                  },
                ),
                // --- FIN DEL CAMBIO ---
              ),
              style: const TextStyle(color: darkBrown),
            ),
            const SizedBox(height: 24),

            // --- MENSAJE DE ERROR ---
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),

            // --- BOTÓN ENTRAR ---
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: _loading ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: darkBrown,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation:
                      0, // Quitamos la elevación para un look más plano/moderno
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                  ), // Ajustar padding
                ),
                child: _loading
                    ? const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      )
                    : const Text(
                        'Entrar',
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),

            // --- BOTONES SECUNDARIOS (ej. ¿Olvidaste tu contraseña?, Registrarse) ---
            TextButton(
              onPressed: () {
                // Navega a la ruta que definimos en GoRouter
                context.push('/forgot-password');
              },
              child: Text(
                '¿Olvidaste tu contraseña?',
                style: TextStyle(color: lightBrownText, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
