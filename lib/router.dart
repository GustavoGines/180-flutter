// lib/router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'feature/auth/loading_page.dart';
import 'feature/auth/login_page.dart';
import 'feature/orders/home_page.dart';
import 'feature/orders/new_order_page.dart';
import 'feature/orders/order_detail_page.dart';
import 'feature/users/presentation/create_user_page.dart';
import 'feature/clients/clients_page.dart';
import 'feature/auth/presentation/forgot_password_page.dart';
import 'feature/auth/presentation/reset_password_page.dart';
import 'feature/auth/auth_state.dart';
import 'feature/clients/client_form_page.dart';
import 'feature/clients/trashed_clients_page.dart';
import 'feature/clients/client_detail_page.dart';
import 'feature/users/presentation/users_list_page.dart';
import 'feature/users/presentation/edit_user_page.dart';

final goRouterNotifierProvider = Provider((ref) => GoRouterNotifier(ref));

class GoRouterNotifier extends ChangeNotifier {
  final Ref _ref;
  GoRouterNotifier(this._ref) {
    _ref.listen<AuthState>(authStateProvider, (_, _) => notifyListeners());
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
        path: '/reset-password', // Ruta para el deep link
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

      // --- NUEVO GRUPO DE RUTAS DE USUARIOS ---
      GoRoute(
        path: '/users',
        builder: (context, state) => const UsersListPage(),
        routes: [
          // Ruta para crear: /users/new
          GoRoute(
            path: 'new',
            builder: (context, state) => const CreateUserPage(),
          ),
          // Ruta para editar: /users/:id/edit
          GoRoute(
            path: ':id/edit',
            builder: (context, state) {
              final id = int.parse(state.pathParameters['id']!);
              return EditUserPage(userId: id);
            },
          ),
        ],
      ),

      // --- NUEVO GRUPO DE RUTAS DE CLIENTES ---
      GoRoute(
        path: '/clients',
        builder: (context, state) => const ClientsPage(), // Muestra la lista
        routes: [
          // Ruta para crear: /clients/new
          GoRoute(
            path: 'new',
            builder: (context, state) => const ClientFormPage(),
          ),
          // Ruta para la papelera: /clients/trashed
          GoRoute(
            path: 'trashed',
            builder: (context, state) => const TrashedClientsPage(),
          ),

          // --- RUTA DE DETALLE (LA QUE FALTABA) ---
          GoRoute(
            path: ':id', // Esto machea /clients/1, /clients/9, etc.
            builder: (context, state) {
              final id = int.parse(state.pathParameters['id']!);
              // Apunta a la PÁGINA DE DETALLE
              return ClientDetailPage(id: id);
            },
            routes: [
              // Sub-ruta para editar: /clients/:id/edit
              GoRoute(
                path: 'edit',
                builder: (context, state) {
                  final id = int.parse(state.pathParameters['id']!);
                  // Apunta a la PÁGINA DE FORMULARIO
                  return ClientFormPage(clientId: id);
                },
              ),
            ],
          ),
        ],
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
      final isGoingToReset = location == '/reset-password';

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
