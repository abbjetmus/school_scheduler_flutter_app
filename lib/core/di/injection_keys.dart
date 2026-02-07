import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart';
import '../../features/attendance/services/ble_reader_service.dart';
import '../../features/attendance/services/attendance_queue_service.dart';
import '../../features/attendance/repositories/attendance_repository.dart';
import '../../features/auth/auth_store.dart' as app_auth;
import '../../features/calendar/calendar_store.dart';
import '../../features/students/students_store.dart';
import '../../features/classes/classes_store.dart';
import '../../features/surveys/surveys_store.dart';
import '../../features/subscriptions/subscriptions_store.dart';
import '../../features/users/users_store.dart';
import '../../features/settings/settings_store.dart';
import '../../features/social_media/social_media_store.dart';
import '../../features/folders_and_files/folders_and_files_store.dart';

// Global Dependency Injection Keys
final pocketBaseKey = InjectionKey<PocketBase>('pocketBase');
final bleReaderServiceKey = InjectionKey<BleReaderService>('bleReaderService');
final attendanceRepositoryKey = InjectionKey<AttendanceRepository>(
  'attendanceRepository',
);
final attendanceQueueServiceKey = InjectionKey<AttendanceQueueService>(
  'attendanceQueueService',
);

// Feature Store Keys
final authStoreKey = InjectionKey<app_auth.AuthStore>('authStore');
final calendarStoreKey = InjectionKey<CalendarStore>('calendarStore');
final studentsStoreKey = InjectionKey<StudentsStore>('studentsStore');
final classesStoreKey = InjectionKey<ClassesStore>('classesStore');
final surveysStoreKey = InjectionKey<SurveysStore>('surveysStore');
final subscriptionsStoreKey = InjectionKey<SubscriptionsStore>(
  'subscriptionsStore',
);
final usersStoreKey = InjectionKey<UsersStore>('usersStore');
final settingsStoreKey = InjectionKey<SettingsStore>('settingsStore');
final socialMediaStoreKey = InjectionKey<SocialMediaStore>('socialMediaStore');
final foldersAndFilesStoreKey = InjectionKey<FoldersAndFilesStore>(
  'foldersAndFilesStore',
);
