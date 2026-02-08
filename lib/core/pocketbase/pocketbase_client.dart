import 'package:pocketbase/pocketbase.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PocketBaseClient {
  static PocketBase? _instance;
  static SharedPreferences? _prefs;

  static Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();

    if (_instance == null) {
      final authStore = AsyncAuthStore(
        save: (String data) async {
          await _prefs!.setString('pb_auth', data);
        },
        initial: _prefs!.getString('pb_auth'),
      );

      // Production PocketBase URL
      const url = 'https://school-scheduler-pb.cloud.mustini.com';

      debugPrint('PocketBaseClient: Using endpoint: $url');

      _instance = PocketBase(url, authStore: authStore);
    }
  }

  static PocketBase get instance {
    if (_instance == null) {
      throw Exception('PocketBaseClient not initialized. Call initialize() first.');
    }
    return _instance!;
  }

  static void dispose() {
    _instance = null;
  }
}
