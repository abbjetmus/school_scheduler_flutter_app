import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:go_router/go_router.dart';

class DashboardPage extends CompositionWidget {
  const DashboardPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    return (context) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Dashboard'),
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;

            return GridView.count(
              crossAxisCount: crossAxisCount,
              padding: const EdgeInsets.all(16),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: [
                _buildFeatureCard(
                  context,
                  icon: Icons.calendar_month,
                  label: 'Haldor Kalender',
                  route: '/haldor-calendar',
                ),
                _buildFeatureCard(
                  context,
                  icon: Icons.school,
                  label: 'Elever',
                  route: '/students',
                ),
                _buildFeatureCard(
                  context,
                  icon: Icons.class_,
                  label: 'Klasser',
                  route: '/classes',
                ),
                _buildFeatureCard(
                  context,
                  icon: Icons.people,
                  label: 'Användare',
                  route: '/users',
                ),
                _buildFeatureCard(
                  context,
                  icon: Icons.poll,
                  label: 'Undersökningar',
                  route: '/surveys',
                ),
                _buildFeatureCard(
                  context,
                  icon: Icons.subscriptions,
                  label: 'Prenumerationer',
                  route: '/subscriptions',
                ),
                _buildFeatureCard(
                  context,
                  icon: Icons.share,
                  label: 'Sociala Medier',
                  route: '/social-media-links',
                ),
                _buildFeatureCard(
                  context,
                  icon: Icons.folder,
                  label: 'Filer & Mappar',
                  route: '/folders-and-files',
                ),
                _buildFeatureCard(
                  context,
                  icon: Icons.how_to_reg,
                  label: 'Närvaroregistrering',
                  route: '/',
                ),
                _buildFeatureCard(
                  context,
                  icon: Icons.settings_bluetooth,
                  label: 'Läsarinställning',
                  route: '/reader-setup',
                ),
                _buildFeatureCard(
                  context,
                  icon: Icons.settings,
                  label: 'Inställningar',
                  route: '/settings',
                ),
              ],
            );
          },
        ),
      );
    };
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String route,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () => context.go(route),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
