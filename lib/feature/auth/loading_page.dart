// lib/feature/auth/loading_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'auth_repository.dart';
import 'auth_state.dart';

class LoadingPage extends ConsumerStatefulWidget {
  const LoadingPage({super.key});

  @override
  ConsumerState<LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends ConsumerState<LoadingPage> {
  @override
  void initState() {
    super.initState();
    // Usamos addPostFrameCallback para asegurarnos de que el widget esté construido
    // antes de intentar cualquier lógica asíncrona o de navegación.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryAutoLogin();
    });
  }

  Future<void> _tryAutoLogin() async {
    // Aseguramos que el widget todavía esté "montado" antes de continuar
    if (!mounted) return;

    debugPrint("--- Verificando sesión ---");
    final authRepo = ref.read(authRepoProvider);

    try {
      final token = await authRepo.getToken();

      if (token != null && token.isNotEmpty) {
        debugPrint(
          "✅ Token encontrado. Intentando obtener datos del usuario...",
        );

        // Si hay token, lo re-inicializamos en Dio para usarlo en la siguiente petición
        await authRepo.init();

        // Pedimos los datos del usuario
        final user = await authRepo.me();
        debugPrint("✅ Usuario '${user.name}' obtenido correctamente.");

        // Actualizamos el estado de la app
        ref.read(authStateProvider.notifier).setUser(user);

        // Navegamos al home
        debugPrint("🚀 Navegando a la página principal...");
        if (mounted) context.go('/');
      } else {
        // Si no hay token, vamos al login
        debugPrint("❌ No se encontró token. Navegando al login...");
        if (mounted) context.go('/login');
      }
    } catch (e) {
      // Si el token es inválido o la API falla, vamos al login
      debugPrint("🚨 Error durante el auto-login: $e");
      debugPrint("❌ Navegando al login...");

      // Es buena práctica limpiar un token que ya no sirve
      await ref.read(authRepoProvider).logout();

      if (mounted) context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Muestra un indicador de carga mientras se verifica la sesión
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('Verificando sesión...'),
          ],
        ),
      ),
    );
  }
}
