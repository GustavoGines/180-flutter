import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'auth_repository.dart'; // Asegúrate de que esta ruta sea correcta
import 'auth_state.dart'; // Asegúrate de que esta ruta sea correcta
import '../../core/services/firebase_messaging_service.dart';

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
  bool _passwordVisible = false;

  static const Color primaryPink = Color(0xFFF9C0C0);
  static const Color darkBrown = Color(0xFF7A4A4A);
  static const Color lightBrownText = Color(0xFFA57D7D);

  @override
  void initState() {
    super.initState();
    ref.read(authRepoProvider).init();
    _passwordVisible = false;
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
        // 1. OBTENEMOS Y SETEAMOS EL USUARIO (como ya lo tenías)
        final user = await ref.read(authRepoProvider).me();
        ref.read(authStateProvider.notifier).setUser(user);

        // ✅ 2. REGISTRAMOS FCM (AQUÍ ES EL LUGAR CORRECTO)
        // Ahora que 'authStateProvider' SÍ tiene el usuario,
        // esta llamada funcionará.
        try {
          await ref.read(firebaseMessagingServiceProvider).init();
          debugPrint('✅ Reinit de FCM tras login exitoso.');
        } catch (e) {
          debugPrint('⚠️ Error al reintentar registro FCM tras login: $e');
        }

        // 3. El router se encargará de navegar solo.
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
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo_180.png',
              height: 350,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 5),
            Text(
              'Bienvenido a 180° Pastelería',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: darkBrown,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _email,
              decoration: InputDecoration(
                labelText: 'Email',
                labelStyle: TextStyle(color: lightBrownText),
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
              ),
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: darkBrown),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _password,
              obscureText: !_passwordVisible,
              decoration: InputDecoration(
                labelText: 'Contraseña',
                labelStyle: TextStyle(color: lightBrownText),
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
                suffixIcon: IconButton(
                  icon: Icon(
                    _passwordVisible ? Icons.visibility : Icons.visibility_off,
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
            ),
            const SizedBox(height: 24),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: _loading ? null : _submit,
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all(darkBrown),
                  shape: WidgetStateProperty.all(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Entrar',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
              ),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () {
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
