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

  AttendanceApiService(this._usbService, this._nfcService);

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
    debugPrint('AttendanceApiService: Registering attendance for cardId=$cardId');
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl$_endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'cardId': cardId}),
      );

      final status = int.tryParse(response.body) ?? 0;
      debugPrint('AttendanceApiService: Response status=$status for cardId=$cardId');

      _playSound(status);
      _resultController.add(AttendanceApiResult(cardId: cardId, status: status));
    } catch (e) {
      debugPrint('AttendanceApiService: Error registering attendance: $e');
      _playSound(0);
      _resultController.add(AttendanceApiResult(cardId: cardId, status: 0));
    }
  }

  void _playSound(int status) {
    if (!_soundEnabled) return;

    final String asset;
    switch (status) {
      case 1:
        asset = 'assets/dog.mp3';
      case 2:
        asset = 'assets/cat.mp3';
      default:
        asset = 'assets/goat.mp3';
    }

    debugPrint('AttendanceApiService: Playing sound $asset');
    _audioPlayer.play(AssetSource(asset.replaceFirst('assets/', '')));
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
