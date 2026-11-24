import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _KioskNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

/// Kioskläget — så att elever inte kan gå ur appen på bibliotekets dator.
///
/// Själva låsningen görs i Windows-delen (windows/runner/kiosk_mode.cpp):
/// helskärm överst, ingen stängning, och Windows-tangenten, Alt+Tab, Alt+F4
/// och Ctrl+Shift+Esc avstängda. Här finns PIN-koden som låser upp, om appen
/// ska starta i kioskläge, och vad appen visar: bara utlåningen, utan meny,
/// utloggning eller val av låntagare.
///
/// Ctrl+Alt+Del kan inget program stänga av. Datorn låses helt genom att
/// appen körs som skal för ett eget Windows-konto — se README.
class KioskStore {
  KioskStore(this._prefs) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'closeRequested') _closeRequests.add(null);
    });
  }

  static const _channel = MethodChannel('skolpunkten/kiosk');
  static const _kPin = 'kiosk.pinHash';
  static const _kAuto = 'kiosk.autoStart';

  final SharedPreferences _prefs;
  final _changes = _KioskNotifier();
  final _closeRequests = StreamController<void>.broadcast();

  final active = ref(false);

  /// Ändras när kioskläget slås på eller av — routern lyssnar på den.
  Listenable get changes => _changes;

  /// Någon försökte stänga fönstret (Alt+F4 går inte, men t.ex. Windows
  /// avstängning eller aktivitetsfältet kan skicka WM_CLOSE).
  Stream<void> get closeRequests => _closeRequests.stream;

  static bool get isSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  bool get hasPin => (_prefs.getString(_kPin) ?? '').isNotEmpty;
  bool get autoStart => _prefs.getBool(_kAuto) ?? false;

  static String _hash(String pin) => sha256.convert(utf8.encode('skolpunkten-bibliotek:$pin')).toString();

  Future<void> setPin(String pin) => _prefs.setString(_kPin, _hash(pin));
  bool verifyPin(String pin) => hasPin && _prefs.getString(_kPin) == _hash(pin);

  Future<void> setAutoStart(bool value) => _prefs.setBool(_kAuto, value);

  Future<void> _native(String method) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<bool>(method);
    } on MissingPluginException {
      // Inte Windows-runnern (t.ex. i tester).
    } catch (e) {
      debugPrint('Kioskläge: $method misslyckades: $e');
    }
  }

  /// Slår på kioskläget. Kräver en PIN-kod, annars kommer ingen ur det.
  Future<bool> enter() async {
    if (!hasPin) return false;
    await _native('enter');
    active.value = true;
    _changes.notify();
    return true;
  }

  /// Låser upp med PIN-koden. Returnerar false om koden är fel.
  Future<bool> unlock(String pin) async {
    if (!verifyPin(pin)) return false;
    await _native('exit');
    active.value = false;
    _changes.notify();
    return true;
  }

  /// Avslutar appen efter rätt PIN-kod.
  Future<bool> quit(String pin) async {
    if (!verifyPin(pin)) return false;
    active.value = false;
    await _native('quit');
    return true;
  }

  /// Släpper låsningen tillfälligt utan PIN — när läraren måste logga in
  /// igen i webbläsaren (inloggningen har gått ut). Läget slås på igen efter
  /// inloggningen om [autoStart] är på.
  Future<void> suspendForLogin() async {
    if (!active.value) return;
    await _native('exit');
    active.value = false;
    _changes.notify();
  }

  void dispose() {
    _closeRequests.close();
  }
}
