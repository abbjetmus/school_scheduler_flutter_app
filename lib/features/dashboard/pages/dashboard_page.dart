import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:go_router/go_router.dart';
import '../../calendar/pages/haldor_calendar_page.dart';
import '../../students/pages/students_list_page.dart';
import '../../classes/pages/classes_list_page.dart';
import '../../users/pages/users_list_page.dart';
import '../../surveys/pages/surveys_list_page.dart';
import '../../subscriptions/pages/subscriptions_list_page.dart';
import '../../social_media/pages/social_media_links_page.dart';
import '../../folders_and_files/pages/folders_and_files_page.dart';
import '../../attendance/pages/attendance_page.dart';
import '../../attendance/pages/reader_setup_page.dart';
import '../../settings/pages/settings_page.dart';

class DashboardPage extends CompositionWidget {
  const DashboardPage({super.key});

  static const String path = '/dashboard';

  @override
  Widget Function(BuildContext) setup() {
    return (context) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dashboard'), automaticallyImplyLeading: false),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 900 ? 6 : (constraints.maxWidth > 600 ? 5 : 4);
            final childAspectRatio = constraints.maxWidth > 900 ? 1.0 : (constraints.maxWidth > 600 ? 0.95 : 0.85);

            return GridView.count(
              crossAxisCount: crossAxisCount,
              padding: const EdgeInsets.all(16),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: childAspectRatio,
              children: [
                _buildFeatureCard(
                  context,
                  icon: Icons.calendar_month,
                  label: 'Haldor Kalender',
                  route: HaldorCalendarPage.path,
                ),
                _buildFeatureCard(context, icon: Icons.school, label: 'Elever', route: StudentsListPage.path),
                _buildFeatureCard(context, icon: Icons.class_, label: 'Klasser', route: ClassesListPage.path),
                _buildFeatureCard(context, icon: Icons.people, label: 'Användare', route: UsersListPage.path),
                _buildFeatureCard(context, icon: Icons.poll, label: 'Undersökningar', route: SurveysListPage.path),
                _buildFeatureCard(
                  context,
                  icon: Icons.subscriptions,
                  label: 'Prenumerationer',
                  route: SubscriptionsListPage.path,
                ),
                _buildFeatureCard(
                  context,
                  icon: Icons.share,
                  label: 'Sociala Medier',
                  route: SocialMediaLinksPage.path,
                ),
                _buildFeatureCard(
                  context,
                  icon: Icons.folder,
                  label: 'Filer & Mappar',
                  route: FoldersAndFilesPage.path,
                ),
                _buildFeatureCard(
                  context,
                  icon: Icons.how_to_reg,
                  label: 'Närvaroregistrering',
                  route: AttendancePage.path,
                ),
                _buildFeatureCard(
                  context,
                  icon: Icons.settings_bluetooth,
                  label: 'Läsarinställning',
                  route: ReaderSetupPage.path,
                ),
                _buildFeatureCard(context, icon: Icons.settings, label: 'Inställningar', route: SettingsPage.path),
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
        onTap: () {
          debugPrint('DashboardPage: Navigating to $route');
          context.push(route);
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 8),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
