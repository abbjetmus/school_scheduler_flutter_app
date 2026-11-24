import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/di/injection_keys.dart';
import 'core/pocketbase/pocketbase_client.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_store.dart';
import 'features/kiosk/kiosk_store.dart';
import 'features/library/circulation_store.dart';
import 'features/library/library_api.dart';
import 'features/reader/keyboard_reader_service.dart';
import 'features/reader/pcsc_reader_service.dart';
import 'features/reader/reader_hub.dart';

/// Skolpunkten Bibliotek — bibliotekets dator. Lärare loggar in en gång;
/// sedan lånar och lämnar elever och lärare böcker genom att blippa.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('sv');
  await PocketBaseClient.initialize();
  runApp(const AppRoot());
}

class AppRoot extends CompositionWidget {
  const AppRoot({super.key, this.fontFamily});

  /// Bara för tester som laddar typsnittet själva — se buildAppTheme.
  final String? fontFamily;

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final pb = PocketBaseClient.instance;
    final authStore = AuthStore(pb);
    final api = LibraryApi(pb);
    final hub = ReaderHub(PcscReaderService(), KeyboardReaderService(), PocketBaseClient.prefs);
    final circulation = CirculationStore(api, hub);
    final kiosk = KioskStore(PocketBaseClient.prefs);

    provide(pocketBaseKey, pb);
    provide(authStoreKey, authStore);
    provide(libraryApiKey, api);
    provide(readerHubKey, hub);
    provide(circulationStoreKey, circulation);
    provide(kioskStoreKey, kiosk);

    final router = createAppRouter(authStore, kiosk);

    // Kioskläget följer inloggningen: på efter inloggning (om det är valt),
    // och tillfälligt av om inloggningen gått ut — läraren måste kunna nå
    // webbläsaren för att logga in igen.
    void onAuthChanged() {
      if (!authStore.isAuthenticated) {
        circulation.endSession();
        unawaited(kiosk.suspendForLogin());
      } else if (kiosk.autoStart && !kiosk.active.value) {
        unawaited(kiosk.enter());
      }
    }

    onMounted(() async {
      authStore.authChanges.addListener(onAuthChanged);
      await hub.autoConnect();
      if (authStore.isAuthenticated) {
        if (kiosk.autoStart) await kiosk.enter();
        await authStore.startSession();
      }
    });

    onUnmounted(() {
      authStore.authChanges.removeListener(onAuthChanged);
      circulation.dispose();
      kiosk.dispose();
      hub.dispose();
    });

    return (context) => MaterialApp.router(
          title: 'Skolpunkten Bibliotek',
          debugShowCheckedModeBanner: false,
          routerConfig: router,
          theme: buildAppTheme(fontFamily: props.value.fontFamily),
          themeMode: ThemeMode.light,
          locale: const Locale('sv'),
          supportedLocales: const [Locale('sv')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        );
  }
}
