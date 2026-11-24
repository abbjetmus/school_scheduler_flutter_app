import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart' show PocketBase;

import '../../features/auth/auth_store.dart';
import '../../features/kiosk/kiosk_store.dart';
import '../../features/library/circulation_store.dart';
import '../../features/library/library_api.dart';
import '../../features/reader/reader_hub.dart';

final pocketBaseKey = InjectionKey<PocketBase>('pocketBase');
final authStoreKey = InjectionKey<AuthStore>('authStore');
final libraryApiKey = InjectionKey<LibraryApi>('libraryApi');
final readerHubKey = InjectionKey<ReaderHub>('readerHub');
final circulationStoreKey = InjectionKey<CirculationStore>('circulationStore');
final kioskStoreKey = InjectionKey<KioskStore>('kioskStore');
