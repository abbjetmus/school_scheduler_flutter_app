import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// PocketBase-klienten. Inloggningen sparas på datorn, så att bibliotekets
/// dator inte behöver loggas in varje morgon.
///
/// Byt server vid test: `flutter run -d windows --dart-define=PB_URL=http://127.0.0.1:8090`
class PocketBaseClient {
  static const url = String.fromEnvironment(
    'PB_URL',
    defaultValue: 'https://school-scheduler-pb.cloud.mustini.com',
  );

  /// Skolpunktens webb — länkar till bokhanteringen där.
  static const webUrl = String.fromEnvironment('WEB_URL', defaultValue: 'https://skolpunkten.se');

  static PocketBase? _instance;
  static SharedPreferences? _prefs;

  static SharedPreferences get prefs => _prefs!;

  static Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
    if (_instance != null) return;
    final authStore = AsyncAuthStore(
      save: (data) async => _prefs!.setString('pb_auth', data),
      clear: () async => _prefs!.remove('pb_auth'),
      initial: _prefs!.getString('pb_auth'),
    );
    debugPrint('PocketBase: $url');
    _instance = PocketBase(url, authStore: authStore, lang: 'sv-SE');
  }

  static PocketBase get instance {
    final pb = _instance;
    if (pb == null) throw StateError('PocketBaseClient.initialize() har inte körts.');
    return pb;
  }
}
