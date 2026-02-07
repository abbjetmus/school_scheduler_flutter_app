import 'package:flutter/foundation.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart';
import '../../core/models/pocketbase_types.dart';
import '../auth/auth_store.dart' as app_auth;

class SurveysStore {
  final PocketBase _pb;
  final app_auth.AuthStore _authStore;

  SurveysStore(this._pb, this._authStore);

  final _surveys = ref<List<SurveyPage>>([]);
  final _loading = ref<bool>(false);

  Ref<List<SurveyPage>> get surveys => _surveys;
  Ref<bool> get loading => _loading;

  Future<bool> fetchAll() async {
    _loading.value = true;
    try {
      final schoolId = _authStore.currentSchoolId;
      final records = await _pb
          .collection(Collections.surveyPages)
          .getFullList(filter: 'school="$schoolId"');
      _surveys.value = records.map((r) => SurveyPage.fromRecord(r)).toList();
      return true;
    } catch (e) {
      debugPrint('SurveysStore: Error fetching surveys: $e');
      return false;
    } finally {
      _loading.value = false;
    }
  }

  Future<SurveyPage?> fetchById(String id) async {
    try {
      final record = await _pb.collection(Collections.surveyPages).getOne(id);
      return SurveyPage.fromRecord(record);
    } catch (e) {
      debugPrint('SurveysStore: Error fetching survey: $e');
      return null;
    }
  }

  Future<bool> create(Map<String, dynamic> data) async {
    try {
      await _pb.collection(Collections.surveyPages).create(body: data);
      await fetchAll();
      return true;
    } catch (e) {
      debugPrint('SurveysStore: Error creating survey: $e');
      return false;
    }
  }

  Future<bool> update(String id, Map<String, dynamic> data) async {
    try {
      await _pb.collection(Collections.surveyPages).update(id, body: data);
      await fetchAll();
      return true;
    } catch (e) {
      debugPrint('SurveysStore: Error updating survey: $e');
      return false;
    }
  }

  Future<bool> delete(String id) async {
    try {
      await _pb.collection(Collections.surveyPages).delete(id);
      _surveys.value = _surveys.value.where((s) => s.id != id).toList();
      return true;
    } catch (e) {
      debugPrint('SurveysStore: Error deleting survey: $e');
      return false;
    }
  }
}
