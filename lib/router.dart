// lib/router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';

// Páginas
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
import 'feature/orders/services/pdf_preview_page.dart';
import 'feature/orders/admin_catalog_page.dart';
import 'feature/orders/admin/product_form_page.dart';
import 'core/models/catalog.dart';

// 🔔 Notificador de GoRouter
final goRouterNotifierProvider = ChangeNotifierProvider((ref) {
  return GoRouterNotifier(ref);
});

class GoRouterNotifier extends ChangeNotifier {
  final Ref _ref;
  GoRouterNotifier(this._ref) {
    _ref.listen<AuthState>(authStateProvider, (prev, next) {
      if (prev?.user != next.user ||
          prev?.initialLoading != next.initialLoading) {
        notifyListeners();
      }
    });
  }
}

// ✅ Router principal
final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.read(goRouterNotifierProvider);

  return GoRouter(
    debugLogDiagnostics: true,
    initialLocation: '/loading',
    refreshListenable: notifier,

    routes: [
      GoRoute(path: '/loading', builder: (_, __) => const LoadingPage()),
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(
        path: '/forgot-password',
        builder: (_, __) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (_, state) {
          final token = state.uri.queryParameters['token'];
          final email = state.uri.queryParameters['email'];
          if (token != null && email != null) {
            return ResetPasswordPage(token: token, email: email);
          }
          return const LoginPage();
        },
      ),
      GoRoute(path: '/', builder: (_, __) => const HomePage()),
      GoRoute(path: '/new_order', builder: (_, __) => const NewOrderPage()),
      GoRoute(
        path: '/order/:id',
        builder: (_, state) =>
            OrderDetailPage(orderId: int.parse(state.pathParameters['id']!)),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (_, state) =>
                NewOrderPage(orderId: int.parse(state.pathParameters['id']!)),
          ),
          GoRoute(
            path: 'pdf/preview',
            builder: (_, state) =>
                PdfPreviewPage(orderId: int.parse(state.pathParameters['id']!)),
          ),
        ],
      ),
      GoRoute(
        path: '/users',
        builder: (_, __) => const UsersListPage(),
        routes: [
          GoRoute(path: 'new', builder: (_, __) => const CreateUserPage()),
          GoRoute(
            path: ':id/edit',
            builder: (_, state) =>
                EditUserPage(userId: int.parse(state.pathParameters['id']!)),
          ),
        ],
      ),
      GoRoute(
        path: '/clients',
        builder: (_, __) => const ClientsPage(),
        routes: [
          GoRoute(path: 'new', builder: (_, __) => const ClientFormPage()),
          GoRoute(
            path: 'trashed',
            builder: (_, __) => const TrashedClientsPage(),
          ),
          GoRoute(
            path: ':id',
            builder: (_, state) =>
                ClientDetailPage(id: int.parse(state.pathParameters['id']!)),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (_, state) => ClientFormPage(
                  clientId: int.parse(state.pathParameters['id']!),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/admin/catalog',
        builder: (_, __) => const AdminCatalogPage(),
        routes: [
          GoRoute(
            path: 'product/new',
            builder: (_, __) => const ProductFormPage(),
          ),
          GoRoute(
            path: 'product/edit',
            builder: (_, state) {
              // Pasamos el producto completo como objeto 'extra'
              final product = state.extra as Product;
              return ProductFormPage(productToEdit: product);
            },
          ),
        ],
      ),
    ],

    // 🔁 Redirección central
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      final isLoading = auth.initialLoading;
      final isLoggedIn = auth.isAuthenticated;

      final loc = state.matchedLocation;
      final atLoading = loc == '/loading';
      final atLogin = loc == '/login';
      final atForgot = loc == '/forgot-password';
      final atReset = loc == '/reset-password';

      // Mientras carga → quedarse en /loading
      if (isLoading) return atLoading ? null : '/loading';

      // Usuario no autenticado
      if (!isLoggedIn && !atLogin && !atForgot && !atReset) {
        debugPrint('🚪 Usuario no logueado → /login');
        Future.microtask(() => context.go('/login'));
        return null;
      }

      // Usuario autenticado pero en login/loading → home
      if (isLoggedIn && (atLogin || atLoading)) {
        debugPrint('🏠 Usuario logueado → /');
        Future.microtask(() => context.go('/'));
        return null;
      }

      return null;
    },
  );
});
