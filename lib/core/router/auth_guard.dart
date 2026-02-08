import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import '../di/injection_keys.dart';

Future<String?> authGuard(BuildContext context, GoRouterState state) async {
  try {
    final authStore = getGlobalAuthStore();
    if (authStore == null) return '/login';

    final isAuthenticated = authStore.isAuthenticated.value;
    final isAuthRoute = state.uri.path == '/login' ||
        state.uri.path == '/register' ||
        state.uri.path == '/forgot-password' ||
        state.uri.path == '/email-verification';

    if (!isAuthenticated && !isAuthRoute) {
      return '/login';
    }

    if (isAuthenticated && isAuthRoute) {
      return '/dashboard';
    }
  } catch (e) {
    return '/login';
  }

  return null;
}
