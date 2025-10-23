// lib/router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'feature/auth/loading_page.dart';
import 'feature/auth/login_page.dart';
import 'feature/orders/home_page.dart';
import 'feature/orders/new_order_page.dart';
import 'feature/orders/order_detail_page.dart';
import 'feature/users/create_user_page.dart';
import 'feature/clients/clients_page.dart';
import 'feature/auth/presentation/forgot_password_page.dart';
import 'feature/auth/presentation/reset_password_page.dart';
import 'feature/auth/auth_state.dart';

final goRouterNotifierProvider = Provider((ref) => GoRouterNotifier(ref));

class GoRouterNotifier extends ChangeNotifier {
  final Ref _ref;
  GoRouterNotifier(this._ref) {
    _ref.listen<AuthState>(authStateProvider, (_, __) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(goRouterNotifierProvider);

  return GoRouter(
    debugLogDiagnostics: true,
    initialLocation: '/loading',
    refreshListenable: notifier,
    routes: [
      GoRoute(
        path: '/loading',
        builder: (context, state) => const LoadingPage(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: '/app/reset-password', // Ruta para el deep link
        builder: (context, state) {
          final token = state.uri.queryParameters['token'];
          final email = state.uri.queryParameters['email'];

          if (token != null && email != null) {
            return ResetPasswordPage(token: token, email: email);
          } else {
            return const LoginPage();
          }
        },
      ),

      GoRoute(path: '/', builder: (context, state) => const HomePage()),

      // --- RUTA MODIFICADA ---
      GoRoute(
        path: '/new_order',
        builder: (context, state) => const NewOrderPage(), // Para crear
      ),
      GoRoute(
        path: '/order/:id/edit', // Para editar
        builder: (context, state) {
          final orderId = int.parse(state.pathParameters['id']!);
          return NewOrderPage(orderId: orderId);
        },
      ),

      // ----------------------
      GoRoute(
        path: '/create_user',
        builder: (context, state) => const CreateUserPage(),
      ),
      GoRoute(
        path: '/clients',
        builder: (context, state) => const ClientsPage(),
      ),
      GoRoute(
        path: '/order/:id',
        builder: (context, state) {
          final orderId = int.parse(state.pathParameters['id']!);
          return OrderDetailPage(orderId: orderId);
        },
      ),
    ],
    redirect: (context, state) {
      final isLoggedIn = ref.read(authStateProvider).isAuthenticated;
      final location = state.matchedLocation;

      final isGoingToLogin = location == '/login';
      final isGoingToLoading = location == '/loading';
      final isGoingToForgotPassword = location == '/forgot-password';
      final isGoingToReset = location == '/app/reset-password';

      if (!isLoggedIn &&
          !isGoingToLogin &&
          !isGoingToLoading &&
          !isGoingToForgotPassword &&
          !isGoingToReset) {
        return '/login';
      }

      if (isLoggedIn && (isGoingToLogin || isGoingToLoading)) {
        return '/';
      }

      return null;
    },
  );
});
