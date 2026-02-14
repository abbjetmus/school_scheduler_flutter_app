import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import '../../features/attendance/pages/attendance_page.dart';
import '../../features/attendance/pages/reader_setup_page.dart';
import '../../features/auth/pages/login_page.dart';
import '../../features/auth/pages/register_page.dart';
import '../../features/auth/pages/forgot_password_page.dart';
import '../../features/auth/pages/email_verification_page.dart';
import '../../features/dashboard/pages/dashboard_page.dart';
import '../../features/calendar/pages/haldor_calendar_page.dart';
import '../../features/students/pages/students_list_page.dart';
import '../../features/students/pages/import_students_page.dart';
import '../../features/students/pages/import_haldor_ids_page.dart';
import '../../features/classes/pages/classes_list_page.dart';
import '../../features/classes/pages/import_classes_page.dart';
import '../../features/surveys/pages/surveys_list_page.dart';
import '../../features/surveys/pages/create_survey_page.dart';
import '../../features/subscriptions/pages/subscriptions_list_page.dart';
import '../../features/subscriptions/pages/create_subscription_page.dart';
import '../../features/users/pages/users_list_page.dart';
import '../../features/settings/pages/settings_page.dart';
import '../../features/social_media/pages/social_media_links_page.dart';
import '../../features/folders_and_files/pages/folders_and_files_page.dart';
import 'auth_guard.dart';

Page<void> _noTransition(Widget child) =>
    NoTransitionPage<void>(child: child);

GoRouter createAppRouter() {
  return GoRouter(
    initialLocation: '/dashboard',
    redirect: authGuard,
    routes: [
      // Auth routes (no shell)
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => _noTransition(const LoginPage()),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (context, state) => _noTransition(const RegisterPage()),
      ),
      GoRoute(
        path: '/forgot-password',
        pageBuilder: (context, state) => _noTransition(const ForgotPasswordPage()),
      ),
      GoRoute(
        path: '/email-verification',
        pageBuilder: (context, state) => _noTransition(EmailVerificationPage(
          token: state.uri.queryParameters['token'],
        )),
      ),

      // Authenticated routes
      GoRoute(
        path: '/dashboard',
        pageBuilder: (context, state) => _noTransition(const DashboardPage()),
      ),
      GoRoute(
        path: '/haldor-calendar',
        pageBuilder: (context, state) => _noTransition(const HaldorCalendarPage()),
      ),

      // Students
      GoRoute(
        path: '/students',
        pageBuilder: (context, state) => _noTransition(const StudentsListPage()),
      ),
      GoRoute(
        path: '/import-students',
        pageBuilder: (context, state) => _noTransition(const ImportStudentsPage()),
      ),
      GoRoute(
        path: '/import-haldor-ids',
        pageBuilder: (context, state) => _noTransition(const ImportHaldorIdsPage()),
      ),

      // Classes
      GoRoute(
        path: '/classes',
        pageBuilder: (context, state) => _noTransition(const ClassesListPage()),
      ),
      GoRoute(
        path: '/import-classes',
        pageBuilder: (context, state) => _noTransition(const ImportClassesPage()),
      ),

      // Surveys
      GoRoute(
        path: '/surveys',
        pageBuilder: (context, state) => _noTransition(const SurveysListPage()),
      ),
      GoRoute(
        path: '/create-survey',
        pageBuilder: (context, state) => _noTransition(const CreateSurveyPage()),
      ),
      GoRoute(
        path: '/edit-survey/:id',
        pageBuilder: (context, state) => _noTransition(CreateSurveyPage(
          surveyId: state.pathParameters['id'],
        )),
      ),

      // Subscriptions
      GoRoute(
        path: '/subscriptions',
        pageBuilder: (context, state) => _noTransition(const SubscriptionsListPage()),
      ),
      GoRoute(
        path: '/create-subscription',
        pageBuilder: (context, state) => _noTransition(const CreateSubscriptionPage()),
      ),
      GoRoute(
        path: '/edit-subscription/:id',
        pageBuilder: (context, state) => _noTransition(CreateSubscriptionPage(
          subscriptionId: state.pathParameters['id'],
        )),
      ),

      // Users
      GoRoute(
        path: '/users',
        pageBuilder: (context, state) => _noTransition(const UsersListPage()),
      ),

      // Settings
      GoRoute(
        path: '/settings',
        pageBuilder: (context, state) => _noTransition(const SettingsPage()),
      ),

      // Social Media
      GoRoute(
        path: '/social-media-links',
        pageBuilder: (context, state) => _noTransition(const SocialMediaLinksPage()),
      ),

      // Folders & Files
      GoRoute(
        path: '/folders-and-files',
        pageBuilder: (context, state) => _noTransition(const FoldersAndFilesPage()),
      ),
      GoRoute(
        path: '/folders-and-files/:id',
        pageBuilder: (context, state) => _noTransition(FoldersAndFilesPage(
          folderId: state.pathParameters['id'],
        )),
      ),

      // Attendance
      GoRoute(
        path: '/',
        pageBuilder: (context, state) => _noTransition(const AttendancePage()),
      ),
      GoRoute(
        path: '/reader-setup',
        pageBuilder: (context, state) => _noTransition(const ReaderSetupPage()),
      ),
    ],
  );
}
