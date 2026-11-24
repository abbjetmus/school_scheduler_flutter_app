import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_store.dart';
import '../../features/auth/pages/login_page.dart';
import '../../features/kiosk/kiosk_store.dart';
import '../../features/library/pages/books_page.dart';
import '../../features/library/pages/cards_page.dart';
import '../../features/library/pages/circulation_page.dart';
import '../../features/library/pages/loans_page.dart';
import '../../features/settings/settings_page.dart';
import '../widgets/app_shell.dart';

Page<void> _page(Widget child) => NoTransitionPage<void>(child: child);

/// Sidorna. Allt utom /login kräver en inloggad lärare eller admin. I
/// kioskläget finns bara utlåningen.
GoRouter createAppRouter(AuthStore auth, KioskStore kiosk) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: Listenable.merge([auth.authChanges, kiosk.changes]),
    redirect: (context, state) {
      final loggedIn = auth.isAuthenticated;
      final atLogin = state.uri.path == '/login';
      if (!loggedIn && !atLogin) return '/login';
      if (loggedIn && atLogin) return '/';
      if (loggedIn && kiosk.active.value && state.uri.path != '/') return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', pageBuilder: (context, state) => _page(const LoginPage())),
      ShellRoute(
        builder: (context, state, child) => AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/', pageBuilder: (context, state) => _page(const CirculationPage())),
          GoRoute(path: '/loans', pageBuilder: (context, state) => _page(const LoansPage())),
          GoRoute(path: '/books', pageBuilder: (context, state) => _page(const BooksPage())),
          GoRoute(path: '/cards', pageBuilder: (context, state) => _page(const CardsPage())),
          GoRoute(path: '/settings', pageBuilder: (context, state) => _page(const SettingsPage())),
        ],
      ),
    ],
  );
}
