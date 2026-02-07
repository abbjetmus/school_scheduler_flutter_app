import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:go_router/go_router.dart';
import '../di/injection_keys.dart';

class AppShell extends CompositionWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  Widget Function(BuildContext) setup() {
    final authStore = inject(authStoreKey);

    return (context) {
      final currentLocation =
          GoRouterState.of(context).uri.toString();
      final userName = authStore.currentUser.value?.name ?? 'User';
      final userEmail = authStore.currentUser.value?.email ?? '';

      return Scaffold(
        appBar: AppBar(
          title: Text(_titleForRoute(currentLocation)),
        ),
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              UserAccountsDrawerHeader(
                accountName: Text(userName),
                accountEmail: Text(userEmail),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Text(
                    userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                    style: const TextStyle(fontSize: 24, color: Colors.blue),
                  ),
                ),
                decoration: const BoxDecoration(color: Colors.blue),
              ),
              _DrawerItem(
                icon: Icons.dashboard,
                label: 'Dashboard',
                route: '/dashboard',
                currentRoute: currentLocation,
              ),
              _DrawerItem(
                icon: Icons.calendar_month,
                label: 'Haldor Kalender',
                route: '/haldor-calendar',
                currentRoute: currentLocation,
              ),
              const Divider(),
              _DrawerItem(
                icon: Icons.people,
                label: 'Elever',
                route: '/students',
                currentRoute: currentLocation,
              ),
              _DrawerItem(
                icon: Icons.class_,
                label: 'Klasser',
                route: '/classes',
                currentRoute: currentLocation,
              ),
              _DrawerItem(
                icon: Icons.person,
                label: 'Användare',
                route: '/users',
                currentRoute: currentLocation,
              ),
              const Divider(),
              _DrawerItem(
                icon: Icons.poll,
                label: 'Undersökningar',
                route: '/surveys',
                currentRoute: currentLocation,
              ),
              _DrawerItem(
                icon: Icons.subscriptions,
                label: 'Prenumerationer',
                route: '/subscriptions',
                currentRoute: currentLocation,
              ),
              _DrawerItem(
                icon: Icons.link,
                label: 'Sociala Medier',
                route: '/social-media-links',
                currentRoute: currentLocation,
              ),
              _DrawerItem(
                icon: Icons.folder,
                label: 'Filer & Mappar',
                route: '/folders-and-files',
                currentRoute: currentLocation,
              ),
              const Divider(),
              _DrawerItem(
                icon: Icons.nfc,
                label: 'Närvaroregistrering',
                route: '/',
                currentRoute: currentLocation,
              ),
              _DrawerItem(
                icon: Icons.bluetooth,
                label: 'Läsarinställning',
                route: '/reader-setup',
                currentRoute: currentLocation,
              ),
              _DrawerItem(
                icon: Icons.settings,
                label: 'Inställningar',
                route: '/settings',
                currentRoute: currentLocation,
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text(
                  'Logga ut',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  authStore.signOut();
                  context.go('/login');
                },
              ),
            ],
          ),
        ),
        body: child,
      );
    };
  }

  String _titleForRoute(String route) {
    if (route.startsWith('/dashboard')) return 'Dashboard';
    if (route.startsWith('/haldor-calendar')) return 'Haldor Kalender';
    if (route.startsWith('/students')) return 'Elever';
    if (route.startsWith('/import-students')) return 'Importera Elever';
    if (route.startsWith('/import-haldor-ids')) return 'Importera Haldor-ID';
    if (route.startsWith('/classes')) return 'Klasser';
    if (route.startsWith('/import-classes')) return 'Importera Klasser';
    if (route.startsWith('/surveys')) return 'Undersökningar';
    if (route.startsWith('/subscriptions')) return 'Prenumerationer';
    if (route.startsWith('/users')) return 'Användare';
    if (route.startsWith('/settings')) return 'Inställningar';
    if (route.startsWith('/social-media-links')) return 'Sociala Medier';
    if (route.startsWith('/folders-and-files')) return 'Filer & Mappar';
    if (route.startsWith('/reader-setup')) return 'Läsarinställning';
    if (route == '/') return 'Närvaroregistrering';
    return 'School Scheduler';
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  final String currentRoute;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = currentRoute == route;
    return ListTile(
      leading: Icon(icon, color: isSelected ? Colors.blue : null),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.blue : null,
        ),
      ),
      selected: isSelected,
      onTap: () {
        Navigator.pop(context); // close drawer
        if (currentRoute != route) {
          context.go(route);
        }
      },
    );
  }
}
