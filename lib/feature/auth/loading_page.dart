import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_repository.dart';
import 'auth_state.dart';

const kSplashBackgroundColor = Color(0xFFFF9999);

class LoadingPage extends ConsumerStatefulWidget {
  const LoadingPage({super.key});

  @override
  ConsumerState<LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends ConsumerState<LoadingPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryAutoLogin());
  }

  Future<void> _tryAutoLogin() async {
    if (!mounted) return;

    debugPrint('--- Verificando sesión ---');
    final authRepo = ref.read(authRepoProvider);
    final authNotifier = ref.read(authStateProvider.notifier);

    try {
      final token = await authRepo.getToken();
      if (token != null && token.isNotEmpty) {
        debugPrint('✅ Token encontrado → obteniendo usuario...');
        await authRepo.init();
        final user = await authRepo.me();

        if (!mounted) return;
        await Future.delayed(const Duration(milliseconds: 600));
        authNotifier.setUser(user);
        debugPrint('🚀 Usuario autenticado');

        // if (mounted) context.go('/'); // 🔹 <--- ELIMINA ESTA LÍNEA
      } else {
        debugPrint('❌ Sin token → actualizando estado...');
        await Future.delayed(const Duration(milliseconds: 300));
        authNotifier.setUser(null);
        // if (mounted) context.go('/login'); // 🔹 <--- ELIMINA ESTA LÍNEA
      }
    } catch (e) {
      debugPrint('🚨 Error en auto-login: $e');
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        await authNotifier.logout();
        // context.go('/login'); // 🔹 <--- ELIMINA ESTA LÍNEA (logout() ya setea user=null)
      }
    } finally {
      // Esta es la línea MÁS IMPORTANTE.
      // Cuando se llama, dispara el redirect del router.
      if (mounted) authNotifier.stopLoading();
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: kSplashBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image(
              image: AssetImage('assets/images/launch_image_solo.png'),
              width: 150,
            ),
            SizedBox(height: 48),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
