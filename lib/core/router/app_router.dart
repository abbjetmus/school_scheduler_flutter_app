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

GoRouter createAppRouter() {
  return GoRouter(
    initialLocation: '/dashboard',
    redirect: authGuard,
    routes: [
      // Auth routes (no shell)
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: '/email-verification',
        builder: (context, state) => EmailVerificationPage(
          token: state.uri.queryParameters['token'],
        ),
      ),

      // Authenticated routes
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardPage(),
      ),
      GoRoute(
        path: '/haldor-calendar',
        builder: (context, state) => const HaldorCalendarPage(),
      ),

      // Students
      GoRoute(
        path: '/students',
        builder: (context, state) => const StudentsListPage(),
      ),
      GoRoute(
        path: '/import-students',
        builder: (context, state) => const ImportStudentsPage(),
      ),
      GoRoute(
        path: '/import-haldor-ids',
        builder: (context, state) => const ImportHaldorIdsPage(),
      ),

      // Classes
      GoRoute(
        path: '/classes',
        builder: (context, state) => const ClassesListPage(),
      ),
      GoRoute(
        path: '/import-classes',
        builder: (context, state) => const ImportClassesPage(),
      ),

      // Surveys
      GoRoute(
        path: '/surveys',
        builder: (context, state) => const SurveysListPage(),
      ),
      GoRoute(
        path: '/create-survey',
        builder: (context, state) => const CreateSurveyPage(),
      ),
      GoRoute(
        path: '/edit-survey/:id',
        builder: (context, state) => CreateSurveyPage(
          surveyId: state.pathParameters['id'],
        ),
      ),

      // Subscriptions
      GoRoute(
        path: '/subscriptions',
        builder: (context, state) => const SubscriptionsListPage(),
      ),
      GoRoute(
        path: '/create-subscription',
        builder: (context, state) => const CreateSubscriptionPage(),
      ),
      GoRoute(
        path: '/edit-subscription/:id',
        builder: (context, state) => CreateSubscriptionPage(
          subscriptionId: state.pathParameters['id'],
        ),
      ),

      // Users
      GoRoute(
        path: '/users',
        builder: (context, state) => const UsersListPage(),
      ),

      // Settings
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
      ),

      // Social Media
      GoRoute(
        path: '/social-media-links',
        builder: (context, state) => const SocialMediaLinksPage(),
      ),

      // Folders & Files
      GoRoute(
        path: '/folders-and-files',
        builder: (context, state) => const FoldersAndFilesPage(),
      ),
      GoRoute(
        path: '/folders-and-files/:id',
        builder: (context, state) => FoldersAndFilesPage(
          folderId: state.pathParameters['id'],
        ),
      ),

      // Attendance
      GoRoute(
        path: '/',
        builder: (context, state) => const AttendancePage(),
      ),
      GoRoute(
        path: '/reader-setup',
        builder: (context, state) => const ReaderSetupPage(),
      ),
    ],
  );
}
