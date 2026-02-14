import 'package:flutter/foundation.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:http/http.dart' as http;
import '../../core/models/pocketbase_types.dart';
import '../auth/auth_store.dart' as app_auth;

class SettingsStore {
  final PocketBase _pb;
  final app_auth.AuthStore _authStore;

  SettingsStore(this._pb, this._authStore);

  final _school = ref<School?>(null);
  final _loading = ref<bool>(false);
  final _token = ref<Token?>(null);
  final _tokenLoading = ref<bool>(false);
  final _syncLoading = ref<bool>(false);

  Ref<School?> get school => _school;
  Ref<bool> get loading => _loading;
  Ref<Token?> get token => _token;
  Ref<bool> get tokenLoading => _tokenLoading;
  Ref<bool> get syncLoading => _syncLoading;

  List<String> get allowedEmailDomains {
    final domains = _school.value?.allowedEmailDomains;
    if (domains == null || domains.isEmpty) return [];
    return domains.split(',').map((d) => d.trim()).where((d) => d.isNotEmpty).toList();
  }

  String? _resolveSchoolId([String? providedId]) {
    return providedId ?? _school.value?.id ?? _authStore.currentSchoolId;
  }

  Future<bool> fetchSchool([String? schoolId]) async {
    final id = _resolveSchoolId(schoolId);
    if (id == null) return false;
    _loading.value = true;
    try {
      final record = await _pb.collection(Collections.schools).getOne(id);
      _school.value = School.fromRecord(record);
      return true;
    } catch (e) {
      debugPrint('SettingsStore: Error fetching school: $e');
      return false;
    } finally {
      _loading.value = false;
    }
  }

  Future<bool> updateSchool(Map<String, dynamic> data) async {
    final id = _resolveSchoolId();
    if (id == null) return false;
    try {
      final record = await _pb.collection(Collections.schools).update(id, body: data);
      _school.value = School.fromRecord(record);
      return true;
    } catch (e) {
      debugPrint('SettingsStore: Error updating school: $e');
      return false;
    }
  }

  Future<bool> updateSchoolName(String name) => updateSchool({'name': name});
  Future<bool> updateSchoolAddress(String address) => updateSchool({'address': address});
  Future<bool> updateHaldorSchoolId(String haldorSchoolId) =>
      updateSchool({'haldorSchoolId': haldorSchoolId});

  Future<bool> updateAllowedEmailDomains(List<String> domains) {
    final normalized = domains
        .map((d) => d.trim().toLowerCase())
        .where((d) => d.isNotEmpty)
        .toSet()
        .join(',');
    return updateSchool({'allowedEmailDomains': normalized});
  }

  Future<bool> updateSchoolColor(String color) {
    final normalized = color.isNotEmpty && !color.startsWith('#') ? '#$color' : color;
    return updateSchool({'color': normalized});
  }

  Future<bool> updateSchoolImage(List<int> fileBytes, String filename) async {
    final id = _resolveSchoolId();
    if (id == null) return false;
    try {
      final multipartFile = http.MultipartFile.fromBytes(
        'image',
        fileBytes,
        filename: filename,
      );
      final record = await _pb
          .collection(Collections.schools)
          .update(id, files: [multipartFile]);
      _school.value = School.fromRecord(record);
      return true;
    } catch (e) {
      debugPrint('SettingsStore: Error updating school image: $e');
      return false;
    }
  }

  Future<bool> fetchToken() async {
    final schoolId = _resolveSchoolId();
    if (schoolId == null) return false;
    _tokenLoading.value = true;
    try {
      final result = await _pb.collection(Collections.tokens).getList(
        filter: 'school="$schoolId"',
        sort: '-created',
        perPage: 1,
      );
      if (result.items.isNotEmpty) {
        _token.value = Token.fromRecord(result.items.first);
      }
      return true;
    } catch (e) {
      debugPrint('SettingsStore: Error fetching token: $e');
      return false;
    } finally {
      _tokenLoading.value = false;
    }
  }

  Future<bool> updateToken(String tokenValue) async {
    final tokenRecord = _token.value;
    if (tokenRecord == null) return false;
    try {
      final updated = await _pb.collection(Collections.tokens).update(
        tokenRecord.id,
        body: {'token': tokenValue},
      );
      _token.value = Token.fromRecord(updated);
      return true;
    } catch (e) {
      debugPrint('SettingsStore: Error updating token: $e');
      return false;
    }
  }

  Future<({bool success, String? error})> syncCalendarEvents(DateTime startTime, DateTime endTime) async {
    _syncLoading.value = true;
    try {
      await _pb.send(
        '/api/haldor/calendar-events/sync',
        method: 'POST',
        body: {
          'startTime': startTime.toUtc().toIso8601String(),
          'endTime': endTime.toUtc().toIso8601String(),
        },
      );
      return (success: true, error: null);
    } catch (e) {
      debugPrint('SettingsStore: Error syncing calendar events: $e');
      return (success: false, error: e.toString());
    } finally {
      _syncLoading.value = false;
    }
  }
}
