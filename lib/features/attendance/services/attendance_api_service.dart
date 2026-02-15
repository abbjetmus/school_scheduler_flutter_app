import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'nfc_reader_service.dart';
import 'usb_reader_service.dart';

class AttendanceApiResult {
  final String cardId;
  final int status; // 0 = error, 1 = check-in, 2 = check-out

  AttendanceApiResult({required this.cardId, required this.status});
}

class AttendanceApiService {
  static const String _baseUrl = 'https://schedule-app.cloud.mustini.com';
  static const String _endpoint = '/api/register-attendance';
  static const String soundEnabledKey = 'attendance_sound_enabled';

  final UsbReaderService _usbService;
  final NfcReaderService _nfcService;
  final AudioPlayer _audioPlayer = AudioPlayer();

  StreamSubscription<String>? _usbSub;
  StreamSubscription<String>? _nfcSub;

  bool _suppressAttendance = false;
  bool _soundEnabled = true;

  final _resultController = StreamController<AttendanceApiResult>.broadcast();
  Stream<AttendanceApiResult> get resultStream => _resultController.stream;

  bool get suppressAttendance => _suppressAttendance;
  set suppressAttendance(bool value) {
    _suppressAttendance = value;
    debugPrint('AttendanceApiService: suppressAttendance = $value');
  }

  bool get soundEnabled => _soundEnabled;
  set soundEnabled(bool value) {
    _soundEnabled = value;
    _saveSoundPreference(value);
    debugPrint('AttendanceApiService: soundEnabled = $value');
  }

  AttendanceApiService(this._usbService, this._nfcService) {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      debugPrint('AttendanceApiService: AudioPlayer state changed to $state');
    });
    _audioPlayer.eventStream.listen((event) {
      debugPrint('AttendanceApiService: AudioPlayer event: ${event.eventType}');
    });
  }

  void start() {
    _loadSoundPreference();
    _usbSub = _usbService.cardIdStream.listen(_onCardScanned);
    _nfcSub = _nfcService.cardIdStream.listen(_onCardScanned);
    debugPrint('AttendanceApiService: Started listening for card scans');
  }

  void stop() {
    _usbSub?.cancel();
    _nfcSub?.cancel();
    _usbSub = null;
    _nfcSub = null;
    debugPrint('AttendanceApiService: Stopped listening');
  }

  void _onCardScanned(String cardId) {
    if (_suppressAttendance) {
      debugPrint('AttendanceApiService: Suppressed (dialog open), skipping attendance for $cardId');
      return;
    }
    _registerAttendance(cardId);
  }

  Future<void> _registerAttendance(String cardId) async {
    final url = '$_baseUrl$_endpoint';
    final requestBody = jsonEncode({'cardId': cardId});
    debugPrint('AttendanceApiService: === REGISTER ATTENDANCE ===');
    debugPrint('AttendanceApiService: URL: $url');
    debugPrint('AttendanceApiService: Request body: $requestBody');
    debugPrint('AttendanceApiService: cardId=$cardId');
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      );

      debugPrint('AttendanceApiService: HTTP ${response.statusCode}');
      debugPrint('AttendanceApiService: Response headers: ${response.headers}');
      debugPrint('AttendanceApiService: Response body: "${response.body}"');

      final status = int.tryParse(response.body) ?? 0;
      debugPrint('AttendanceApiService: Parsed status=$status (0=error, 1=check-in, 2=check-out)');

      _playSound(status);
      _resultController.add(AttendanceApiResult(cardId: cardId, status: status));
    } catch (e, stackTrace) {
      debugPrint('AttendanceApiService: ERROR calling API: $e');
      debugPrint('AttendanceApiService: Stack trace: $stackTrace');
      _playSound(0);
      _resultController.add(AttendanceApiResult(cardId: cardId, status: 0));
    }
  }

  Future<void> _playSound(int status) async {
    if (!_soundEnabled) {
      debugPrint('AttendanceApiService: Sound disabled, skipping');
      return;
    }

    final String assetName;
    switch (status) {
      case 1:
        assetName = 'dog.mp3';
      case 2:
        assetName = 'cat.mp3';
      default:
        assetName = 'goat.mp3';
    }

    debugPrint('AttendanceApiService: Playing sound $assetName for status=$status');
    debugPrint('AttendanceApiService: AudioPlayer state=${_audioPlayer.state}');
    debugPrint('AttendanceApiService: AudioPlayer source=AssetSource($assetName)');

    try {
      await _audioPlayer.stop();
      debugPrint('AttendanceApiService: Stopped previous playback');

      await _audioPlayer.setSource(AssetSource(assetName));
      debugPrint('AttendanceApiService: Source set successfully');

      await _audioPlayer.resume();
      debugPrint('AttendanceApiService: Playback started, state=${_audioPlayer.state}');
    } catch (e, stackTrace) {
      debugPrint('AttendanceApiService: ERROR playing sound: $e');
      debugPrint('AttendanceApiService: Stack trace: $stackTrace');
    }
  }

  Future<void> _loadSoundPreference() async {
    final prefs = await SharedPreferences.getInstance();
    _soundEnabled = prefs.getBool(soundEnabledKey) ?? true;
    debugPrint('AttendanceApiService: Loaded soundEnabled = $_soundEnabled');
  }

  Future<void> _saveSoundPreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(soundEnabledKey, value);
  }

  void dispose() {
    stop();
    _audioPlayer.dispose();
    _resultController.close();
  }
}
