import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:nfc_manager/nfc_manager.dart';

/// Platform-aware NFC reading service.
/// Uses nfc_manager on Android/iOS, falls back to manual input on desktop.
class NfcReaderService {
  final _cardIdController = StreamController<String>.broadcast();
  Stream<String> get cardIdStream => _cardIdController.stream;

  bool _isSessionActive = false;
  bool get isSessionActive => _isSessionActive;

  final _sessionActiveController = StreamController<bool>.broadcast();
  Stream<bool> get sessionActiveStream => _sessionActiveController.stream;

  /// Whether this platform supports native NFC reading.
  static bool get isNfcSupported {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  /// Check if NFC hardware is available and enabled on this device.
  Future<bool> isNfcAvailable() async {
    if (!isNfcSupported) return false;
    try {
      return await NfcManager.instance.isAvailable();
    } catch (e) {
      debugPrint('NFC: Error checking availability: $e');
      return false;
    }
  }

  /// Start continuous NFC reading session (Android/iOS only).
  /// Each scanned tag's UID is emitted on [cardIdStream].
  Future<void> startSession() async {
    if (!isNfcSupported) return;
    if (_isSessionActive) return;

    _isSessionActive = true;
    _sessionActiveController.add(true);

    NfcManager.instance.startSession(
      pollingOptions: {
        NfcPollingOption.iso14443,
        NfcPollingOption.iso15693,
      },
      onDiscovered: (NfcTag tag) async {
        final uid = _extractUid(tag);
        if (uid != null && uid.isNotEmpty) {
          debugPrint('NFC: Card UID: $uid');
          _cardIdController.add(uid);
        }

        // On iOS, briefly stop and restart to allow next scan
        // On Android, session stays active automatically
        if (Platform.isIOS) {
          await NfcManager.instance.stopSession(alertMessage: 'Kort skannat!');
          // Restart session for next card
          await Future.delayed(const Duration(milliseconds: 500));
          if (_isSessionActive) {
            startSession();
          }
        }
      },
    );

    debugPrint('NFC: Session started');
  }

  /// Stop the NFC reading session.
  Future<void> stopSession() async {
    if (!_isSessionActive) return;
    _isSessionActive = false;
    _sessionActiveController.add(false);

    if (isNfcSupported) {
      try {
        await NfcManager.instance.stopSession();
      } catch (e) {
        debugPrint('NFC: Error stopping session: $e');
      }
    }

    debugPrint('NFC: Session stopped');
  }

  /// Submit a card ID from manual input (works on all platforms).
  void submitCardId(String cardId) {
    final trimmed = cardId.trim();
    if (trimmed.isNotEmpty) {
      debugPrint('NFC: Manual card ID: $trimmed');
      _cardIdController.add(trimmed);
    }
  }

  /// Extract UID from an NFC tag, trying different tag types.
  String? _extractUid(NfcTag tag) {
    // Try NFC-A (most common — MIFARE, NTAG, etc.)
    final nfcA = NfcA.from(tag);
    if (nfcA != null) {
      return _bytesToHex(nfcA.identifier);
    }

    // Try NFC-B
    final nfcB = NfcB.from(tag);
    if (nfcB != null) {
      return _bytesToHex(nfcB.identifier);
    }

    // Try NFC-F (FeliCa)
    final nfcF = NfcF.from(tag);
    if (nfcF != null) {
      return _bytesToHex(nfcF.identifier);
    }

    // Try NFC-V (ISO 15693)
    final nfcV = NfcV.from(tag);
    if (nfcV != null) {
      return _bytesToHex(nfcV.identifier);
    }

    debugPrint('NFC: Unknown tag type, raw data: ${tag.data}');
    return null;
  }

  String _bytesToHex(List<int> bytes) {
    return bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join('')
        .toUpperCase();
  }

  void dispose() {
    stopSession();
    _cardIdController.close();
    _sessionActiveController.close();
  }
}
