import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/user.dart';
import 'auth_repository.dart'; // Importamos el repositorio

// Define la estructura del estado de autenticación
class AuthState {
  final AppUser? user; // El usuario autenticado, o null si no lo está.
  final bool initialLoading; // true mientras se verifica el token al inicio.
  const AuthState({this.user, this.initialLoading = true});

  bool get isAuthenticated => user != null;

  AuthState copyWith({AppUser? user, bool? initialLoading}) => AuthState(
    user: user,
    initialLoading: initialLoading ?? this.initialLoading,
  );
}

// Controlador con la lógica para manipular el estado
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  void setUser(AppUser? u) =>
      state = state.copyWith(user: u, initialLoading: false);
  void stopLoading() => state = state.copyWith(initialLoading: false);

  Future<void> logout() async {
    // Llama al repositorio para hacer el logout en el backend y localmente
    await ref.read(authRepoProvider).logout();

    // Actualiza el estado de la app a "no autenticado"
    state = const AuthState(initialLoading: false);
  }
}

// Provider para acceder al AuthController y su estado desde la UI
final authStateProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
