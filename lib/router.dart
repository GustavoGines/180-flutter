// lib/router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

// ✅ Función de transición Fade
CustomTransitionPage<T> _fadePageBuilder<T>(BuildContext context, GoRouterState state, Widget child) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

// ✅ Router principal
final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.read(goRouterNotifierProvider);

  return GoRouter(
    debugLogDiagnostics: true,
    initialLocation: '/loading',
    refreshListenable: notifier,

    routes: [
      GoRoute(path: '/loading', pageBuilder: (context, state) => _fadePageBuilder(context, state, const LoadingPage())),
      GoRoute(path: '/login', pageBuilder: (context, state) => _fadePageBuilder(context, state, const LoginPage())),
      GoRoute(
        path: '/forgot-password',
        pageBuilder: (context, state) => _fadePageBuilder(context, state, const ForgotPasswordPage()),
      ),
      GoRoute(
        path: '/reset-password',
        pageBuilder: (context, state) {
          final token = state.uri.queryParameters['token'];
          final email = state.uri.queryParameters['email'];
          if (token != null && email != null) {
            return _fadePageBuilder(context, state, ResetPasswordPage(token: token, email: email));
          }
          return _fadePageBuilder(context, state, const LoginPage());
        },
      ),
      GoRoute(path: '/', pageBuilder: (context, state) => _fadePageBuilder(context, state, const HomePage())),
      GoRoute(path: '/new_order', pageBuilder: (context, state) => _fadePageBuilder(context, state, const NewOrderPage())),
      GoRoute(
        path: '/order/:id',
        pageBuilder: (context, state) =>
            _fadePageBuilder(context, state, OrderDetailPage(orderId: int.parse(state.pathParameters['id']!))),
        routes: [
          GoRoute(
            path: 'edit',
            pageBuilder: (context, state) =>
                _fadePageBuilder(context, state, NewOrderPage(orderId: int.parse(state.pathParameters['id']!))),
          ),
          GoRoute(
            path: 'pdf/preview',
            pageBuilder: (context, state) =>
                _fadePageBuilder(context, state, PdfPreviewPage(orderId: int.parse(state.pathParameters['id']!))),
          ),
        ],
      ),
      GoRoute(
        path: '/users',
        pageBuilder: (context, state) => _fadePageBuilder(context, state, const UsersListPage()),
        routes: [
          GoRoute(path: 'new', pageBuilder: (context, state) => _fadePageBuilder(context, state, const CreateUserPage())),
          GoRoute(
            path: ':id/edit',
            pageBuilder: (context, state) =>
                _fadePageBuilder(context, state, EditUserPage(userId: int.parse(state.pathParameters['id']!))),
          ),
        ],
      ),
      GoRoute(
        path: '/clients',
        pageBuilder: (context, state) => _fadePageBuilder(context, state, const ClientsPage()),
        routes: [
          GoRoute(path: 'new', pageBuilder: (context, state) => _fadePageBuilder(context, state, const ClientFormPage())),
          GoRoute(
            path: 'trashed',
            pageBuilder: (context, state) => _fadePageBuilder(context, state, const TrashedClientsPage()),
          ),
          GoRoute(
            path: ':id',
            pageBuilder: (context, state) =>
                _fadePageBuilder(context, state, ClientDetailPage(id: int.parse(state.pathParameters['id']!))),
            routes: [
              GoRoute(
                path: 'edit',
                pageBuilder: (context, state) => _fadePageBuilder(context, state, ClientFormPage(
                  clientId: int.parse(state.pathParameters['id']!),
                )),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/admin/catalog',
        pageBuilder: (context, state) => _fadePageBuilder(context, state, const AdminCatalogPage()),
        routes: [
          GoRoute(
            path: 'product/new',
            pageBuilder: (context, state) => _fadePageBuilder(context, state, const ProductFormPage()),
          ),
          GoRoute(
            path: 'product/edit',
            pageBuilder: (context, state) {
              final product = state.extra as Product;
              return _fadePageBuilder(context, state, ProductFormPage(productToEdit: product));
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
        return '/login';
      }

      // Usuario autenticado pero en login/loading → home
      if (isLoggedIn && (atLogin || atLoading)) {
        debugPrint('🏠 Usuario logueado → /');
        return '/';
      }

      return null;
    },
  );
});
