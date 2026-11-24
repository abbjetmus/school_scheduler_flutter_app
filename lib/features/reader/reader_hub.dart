import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'keyboard_reader_service.dart';
import 'pcsc_reader_service.dart';

/// Alla läsare i en ström: PC/SC-läsaren, tangentbordsläsare och koder som
/// skrivs in för hand. Sidorna lyssnar på [codes] medan de visas.
///
/// Här finns också läsarinställningarna (sparas på datorn) och ljuden som
/// talar om att något hände — bibliotekarien tittar på boken, inte skärmen.
class ReaderHub {
  ReaderHub(this.pcsc, this.keyboard, this._prefs) {
    _pcscSub = pcsc.codes.listen(_codeController.add);
    _keyboardSub = keyboard.codes.listen(_codeController.add);
    keyboard.enabled = keyboardEnabled;
    keyboard.attach();
  }

  final PcscReaderService pcsc;
  final KeyboardReaderService keyboard;
  final SharedPreferences _prefs;

  final _codeController = StreamController<String>.broadcast();
  late final StreamSubscription<String> _pcscSub;
  late final StreamSubscription<String> _keyboardSub;
  /// Ljuden spelas av Windows-delen (windows/runner/sound_channel.cpp).
  static const _sound = MethodChannel('skolpunkten/sound');

  Stream<String> get codes => _codeController.stream;

  /// En kod som skrivits in för hand.
  void submit(String code) {
    final trimmed = code.trim();
    if (trimmed.isNotEmpty) _codeController.add(trimmed);
  }

  // ── Inställningar ─────────────────────────────────────────────────────

  static const _kReader = 'reader.pcscName';
  static const _kKeyboard = 'reader.keyboard';
  static const _kSounds = 'reader.sounds';
  static const _kTimeout = 'circulation.timeoutSeconds';

  String? get preferredReader => _prefs.getString(_kReader);
  bool get keyboardEnabled => _prefs.getBool(_kKeyboard) ?? true;
  bool get soundsEnabled => _prefs.getBool(_kSounds) ?? true;

  /// Sekunder utan aktivitet innan låntagaren loggas ut från disken.
  int get sessionTimeoutSeconds => _prefs.getInt(_kTimeout) ?? 45;

  Future<void> setKeyboardEnabled(bool value) async {
    keyboard.enabled = value;
    await _prefs.setBool(_kKeyboard, value);
  }

  Future<void> setSoundsEnabled(bool value) => _prefs.setBool(_kSounds, value);
  Future<void> setSessionTimeoutSeconds(int value) => _prefs.setInt(_kTimeout, value);

  /// Ansluter till läsaren och kommer ihåg den till nästa start.
  Future<void> useReader(String? name) async {
    if (name == null) {
      await pcsc.disconnect();
      await _prefs.remove(_kReader);
      return;
    }
    await pcsc.connect(name);
    await _prefs.setString(_kReader, name);
  }

  /// Vid start: den sparade läsaren, eller den enda som sitter i.
  Future<void> autoConnect() async {
    if (!PcscReaderService.isSupported) return;
    final readers = await pcsc.listReaders();
    final saved = preferredReader;
    final pick = saved != null && readers.contains(saved) ? saved : (readers.length == 1 ? readers.first : null);
    if (pick != null) await pcsc.connect(pick);
  }

  // ── Ljud ──────────────────────────────────────────────────────────────

  Future<void> _play(String name) async {
    if (!soundsEnabled) return;
    try {
      await _sound.invokeMethod<bool>('play', name);
    } on MissingPluginException {
      // Inte Windows-runnern (t.ex. i tester).
    } catch (e) {
      debugPrint('Ljud: $e');
    }
  }

  void playSuccess() => _play('success');
  void playCard() => _play('card');
  void playError() {
    pcsc.forgetLast();
    _play('error');
  }

  void dispose() {
    _pcscSub.cancel();
    _keyboardSub.cancel();
    keyboard.dispose();
    pcsc.dispose();
    _codeController.close();
  }
}
