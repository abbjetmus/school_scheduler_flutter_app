import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'features/attendance/repositories/attendance_repository.dart';
import 'features/attendance/services/nfc_reader_service.dart';
import 'features/attendance/services/usb_reader_service.dart';
import 'features/attendance/services/attendance_queue_service.dart';
import 'features/auth/auth_store.dart' as app_auth;
import 'features/calendar/calendar_store.dart';
import 'features/students/students_store.dart';
import 'features/classes/classes_store.dart';
import 'features/surveys/surveys_store.dart';
import 'features/subscriptions/subscriptions_store.dart';
import 'features/users/users_store.dart';
import 'features/settings/settings_store.dart';
import 'features/social_media/social_media_store.dart';
import 'features/folders_and_files/folders_and_files_store.dart';
import 'core/di/injection_keys.dart';
import 'core/router/app_router.dart';
import 'core/pocketbase/pocketbase_client.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize PocketBase with AsyncAuthStore for session persistence
  await PocketBaseClient.initialize();

  runApp(const AppRoot());
}

class AppRoot extends CompositionWidget {
  const AppRoot({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final pb = PocketBaseClient.instance;
    final attendanceRepo = AttendanceRepository(pb);
    final authStore = app_auth.AuthStore(pb);

    // Existing attendance services
    provide(pocketBaseKey, pb);
    provide(nfcReaderServiceKey, NfcReaderService());
    provide(usbReaderServiceKey, UsbReaderService());
    provide(attendanceRepositoryKey, attendanceRepo);
    provide(attendanceQueueServiceKey, AttendanceQueueService(attendanceRepo));

    // Feature stores
    provide(authStoreKey, authStore);
    provide(calendarStoreKey, CalendarStore(pb));
    provide(studentsStoreKey, StudentsStore(pb, authStore));
    provide(classesStoreKey, ClassesStore(pb, authStore));
    provide(surveysStoreKey, SurveysStore(pb, authStore));
    provide(subscriptionsStoreKey, SubscriptionsStore(pb, authStore));
    provide(usersStoreKey, UsersStore(pb, authStore));
    provide(settingsStoreKey, SettingsStore(pb, authStore));
    provide(socialMediaStoreKey, SocialMediaStore(pb, authStore));
    provide(foldersAndFilesStoreKey, FoldersAndFilesStore(pb, authStore));

    // Set global auth store for router guard
    setGlobalAuthStore(authStore);

    final router = createAppRouter();

    return (context) => MaterialApp.router(
      title: 'School Scheduler',
      routerConfig: router,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue), useMaterial3: true),
    );
  }
}
