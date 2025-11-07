import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/user.dart';
import 'auth_repository.dart';

class AuthState {
  final AppUser? user;
  final bool initialLoading;
  const AuthState({this.user, this.initialLoading = true});

  bool get isAuthenticated => user != null;

  AuthState copyWith({AppUser? user, bool? initialLoading}) => AuthState(
    user: user ?? this.user,
    initialLoading: initialLoading ?? this.initialLoading,
  );
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  void setUser(AppUser? u) {
    // ⚡ Aseguramos que siempre apague el loading
    state = state.copyWith(user: u, initialLoading: false);

    debugPrint(
      u != null
          ? "✅ Usuario logueado: ${u.name}"
          : "🚪 Sesión cerrada (setUser null)",
    );

    if (u != null) {
      // Opcional: al loguearse, podemos iniciar FCM aquí directamente
      // ref.read(firebaseMessagingServiceProvider).init();
    }
  }

  void stopLoading() {
    state = state.copyWith(initialLoading: false);
  }

  Future<void> logout() async {
    await ref.read(authRepoProvider).logout();
    state = const AuthState(initialLoading: false);
  }
}

final authStateProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

final authTokenProvider = FutureProvider<String?>((ref) async {
  final authRepo = ref.read(authRepoProvider);
  return await authRepo.getToken();
});
