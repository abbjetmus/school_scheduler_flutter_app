import 'dart:async';
import 'package:dart_pcsc/dart_pcsc.dart';
import 'package:flutter/foundation.dart';

enum UsbReaderState { disconnected, connecting, connected, polling, error }

class UsbReaderService {
  Context? _context;
  String? _connectedReaderName;
  bool _polling = false;

  final _stateController = StreamController<UsbReaderState>.broadcast();
  final _cardIdController = StreamController<String>.broadcast();

  Stream<UsbReaderState> get stateStream => _stateController.stream;
  Stream<String> get cardIdStream => _cardIdController.stream;

  UsbReaderState _state = UsbReaderState.disconnected;
  UsbReaderState get state => _state;

  String? get connectedReaderName => _connectedReaderName;

  /// Last card ID to deduplicate rapid reads of the same card.
  String? _lastCardId;
  DateTime? _lastCardTime;

  /// Whether USB PC/SC readers are supported on this platform.
  static bool get isSupported {
    if (kIsWeb) return false;
    // dart_pcsc supports Windows, macOS, and Linux via native PC/SC APIs
    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  void _setState(UsbReaderState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  /// Establish the PC/SC context. Must be called before other operations.
  Future<void> initialize() async {
    if (!isSupported) return;
    try {
      _context = Context(Scope.user);
      await _context!.establish();
      debugPrint('USB-PCSC: Context established');
    } catch (e) {
      debugPrint('USB-PCSC: Failed to establish context: $e');
      _context = null;
    }
  }

  /// List available USB smart card readers.
  Future<List<String>> listReaders() async {
    if (_context == null) await initialize();
    if (_context == null) return [];

    try {
      final readers = await _context!.listReaders();
      debugPrint('USB-PCSC: Found ${readers.length} reader(s): $readers');
      return readers;
    } catch (e) {
      debugPrint('USB-PCSC: Error listing readers: $e');
      return [];
    }
  }

  /// Connect to a specific reader and start polling for cards.
  Future<void> connectToReader(String readerName) async {
    if (_context == null) await initialize();
    if (_context == null) {
      _setState(UsbReaderState.error);
      return;
    }

    _connectedReaderName = readerName;
    _setState(UsbReaderState.connected);
    debugPrint('USB-PCSC: Connected to reader: $readerName');

    // Start polling for cards
    _startPolling(readerName);
  }

  /// Start continuous polling for cards on the connected reader.
  void _startPolling(String readerName) {
    if (_polling) return;
    _polling = true;
    _setState(UsbReaderState.polling);

    _pollLoop(readerName);
  }

  Future<void> _pollLoop(String readerName) async {
    debugPrint('USB-PCSC: Polling for cards on $readerName...');
    bool cardWasPresent = false;

    while (_polling && _context != null) {
      try {
        // Try to connect — succeeds only if a card is present
        final card = await _context!.connect(
          readerName,
          ShareMode.shared,
          Protocol.any,
        );

        if (!cardWasPresent) {
          // New card detected — read UID
          cardWasPresent = true;
          await _readCardUidFromCard(card);
        }

        await card.disconnect(Disposition.leaveCard);
        // Card still present, wait before checking again
        await Future.delayed(const Duration(milliseconds: 300));
      } catch (_) {
        // No card present (connect failed)
        if (cardWasPresent) {
          debugPrint('USB-PCSC: Card removed');
          cardWasPresent = false;
        }
        // Wait before next poll attempt
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
  }

  /// Read the UID from an already-connected card.
  Future<void> _readCardUidFromCard(Card card) async {
    try {
      // APDU: Get UID (FF CA 00 00 00)
      // FF = class (pseudo-APDU for reader)
      // CA = instruction (Get Data / Get UID)
      // 00 00 = P1 P2
      // 00 = Le (return all available bytes)
      final getUidCommand = Uint8List.fromList([0xFF, 0xCA, 0x00, 0x00, 0x00]);
      final response = await card.transmit(getUidCommand);

      if (response.length >= 2) {
        // Last 2 bytes are status word (SW1 SW2)
        final sw1 = response[response.length - 2];
        final sw2 = response[response.length - 1];

        if (sw1 == 0x90 && sw2 == 0x00) {
          // Success — UID is everything except the last 2 bytes
          final uidBytes = response.sublist(0, response.length - 2);
          final uid = _bytesToHex(uidBytes);
          debugPrint('USB-PCSC: Card UID: $uid');
          _emitCardId(uid);
        } else {
          debugPrint(
            'USB-PCSC: Get UID failed with SW: '
            '${sw1.toRadixString(16).padLeft(2, '0')} '
            '${sw2.toRadixString(16).padLeft(2, '0')}',
          );
        }
      }
    } catch (e) {
      debugPrint('USB-PCSC: Error reading card UID: $e');
    }
  }

  /// Emit a card ID, with deduplication to avoid rapid repeats.
  void _emitCardId(String hexId) {
    final now = DateTime.now();

    // Deduplicate: ignore same card within 2 seconds
    if (_lastCardId == hexId &&
        _lastCardTime != null &&
        now.difference(_lastCardTime!).inMilliseconds < 2000) {
      return;
    }

    _lastCardId = hexId;
    _lastCardTime = now;
    debugPrint('USB-PCSC: >>> CARD ID EMITTED: $hexId <<<');
    _cardIdController.add(hexId);
  }

  String _bytesToHex(Uint8List bytes) {
    return bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join('')
        .toUpperCase();
  }

  /// Submit a card ID from manual input.
  void submitCardId(String cardId) {
    final trimmed = cardId.trim();
    if (trimmed.isNotEmpty) {
      debugPrint('USB-PCSC: Manual card ID: $trimmed');
      _cardIdController.add(trimmed);
    }
  }

  /// Disconnect from the reader and stop polling.
  Future<void> disconnect() async {
    _polling = false;
    _connectedReaderName = null;
    _setState(UsbReaderState.disconnected);
    debugPrint('USB-PCSC: Disconnected');
  }

  /// Release the PC/SC context and clean up.
  void dispose() {
    _polling = false;
    try {
      _context?.release();
    } catch (_) {}
    _context = null;
    _stateController.close();
    _cardIdController.close();
  }
}
