import 'dart:async';

import 'package:dart_pcsc/dart_pcsc.dart';
import 'package:flutter/foundation.dart';

enum PcscReaderState { unsupported, disconnected, polling, error }

/// USB-läsare via PC/SC (Windows — appen körs bara där). Läser UID:t på det som
/// läggs på läsaren med APDU:n FF CA 00 00 00 — det fungerar för både
/// bibliotekets RFID-etiketter (ISO 15693, t.ex. NXP ICODE SLIX) och
/// passerkort (ISO 14443, MIFARE) på läsare som klarar båda, till exempel
/// ACS ACR1552U. En RC522 (Arduino-läsaren) klarar inte ISO 15693.
///
/// Tjänst utan refs: läget och koderna kommer som strömmar.
class PcscReaderService {
  Context? _context;
  String? _readerName;
  bool _polling = false;
  int _generation = 0;

  final _stateController = StreamController<PcscReaderState>.broadcast();
  final _codeController = StreamController<String>.broadcast();

  Stream<PcscReaderState> get stateStream => _stateController.stream;
  Stream<String> get codes => _codeController.stream;

  PcscReaderState _state = PcscReaderState.disconnected;
  PcscReaderState get state => isSupported ? _state : PcscReaderState.unsupported;
  String? get readerName => _readerName;

  String? _lastCode;
  DateTime? _lastTime;

  static bool get isSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  void _setState(PcscReaderState value) {
    _state = value;
    _stateController.add(value);
  }

  Future<bool> _ensureContext() async {
    if (!isSupported) return false;
    if (_context != null) return true;
    try {
      _context = Context(Scope.user);
      await _context!.establish();
      return true;
    } catch (e) {
      debugPrint('PC/SC: kunde inte starta: $e');
      _context = null;
      return false;
    }
  }

  /// Anslutna läsare. Tom lista om PC/SC saknas eller ingen läsare sitter i.
  Future<List<String>> listReaders() async {
    if (!await _ensureContext()) return [];
    try {
      return await _context!.listReaders();
    } catch (e) {
      // "No readers available" kastas som fel.
      debugPrint('PC/SC: inga läsare: $e');
      return [];
    }
  }

  /// Börjar lyssna på en läsare. Byter läsare om en annan redan används.
  Future<void> connect(String readerName) async {
    if (!await _ensureContext()) {
      _setState(PcscReaderState.error);
      return;
    }
    _polling = false;
    _readerName = readerName;
    _polling = true;
    _setState(PcscReaderState.polling);
    unawaited(_pollLoop(readerName, ++_generation));
  }

  Future<void> _pollLoop(String readerName, int generation) async {
    var present = false;
    var read = false;
    while (_polling && generation == _generation && _context != null) {
      try {
        final card = await _context!.connect(readerName, ShareMode.shared, Protocol.any);
        if (!present) {
          present = true;
          read = false;
        }
        if (!read) read = await _readUid(card);
        await card.disconnect(Disposition.leaveCard);
        await Future<void>.delayed(const Duration(milliseconds: 250));
      } catch (_) {
        // Inget på läsaren.
        present = false;
        read = false;
        await Future<void>.delayed(const Duration(milliseconds: 350));
      }
    }
  }

  Future<bool> _readUid(Card card) async {
    try {
      final response = await card.transmit(Uint8List.fromList([0xFF, 0xCA, 0x00, 0x00, 0x00]));
      if (response.length < 2) return false;
      final sw1 = response[response.length - 2];
      final sw2 = response[response.length - 1];
      if (sw1 != 0x90 || sw2 != 0x00) return false;
      final uid = response
          .sublist(0, response.length - 2)
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join()
          .toUpperCase();
      if (uid.isEmpty) return false;
      _emit(uid);
      return true;
    } catch (e) {
      debugPrint('PC/SC: kunde inte läsa UID: $e');
      return false;
    }
  }

  /// Samma etikett som ligger kvar på läsaren skickas inte igen inom 2 s.
  void _emit(String code) {
    final now = DateTime.now();
    if (_lastCode == code && _lastTime != null && now.difference(_lastTime!).inMilliseconds < 2000) return;
    _lastCode = code;
    _lastTime = now;
    _codeController.add(code);
  }

  /// Låter samma kod läsas igen direkt (efter t.ex. ett fel).
  void forgetLast() {
    _lastCode = null;
    _lastTime = null;
  }

  Future<void> disconnect() async {
    _polling = false;
    _generation++;
    _readerName = null;
    _setState(PcscReaderState.disconnected);
  }

  void dispose() {
    _polling = false;
    try {
      _context?.release();
    } catch (_) {}
    _context = null;
    _stateController.close();
    _codeController.close();
  }
}
