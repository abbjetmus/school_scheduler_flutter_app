import 'package:flutter/foundation.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart';
import '../../core/models/pocketbase_types.dart';
import '../auth/auth_store.dart' as app_auth;

class ClassesStore {
  final PocketBase _pb;
  final app_auth.AuthStore _authStore;

  ClassesStore(this._pb, this._authStore);

  final _classes = ref<List<ClassGroup>>([]);
  final _loading = ref<bool>(false);

  Ref<List<ClassGroup>> get classes => _classes;
  Ref<bool> get loading => _loading;

  Future<bool> getClasses() async {
    _loading.value = true;
    try {
      final schoolId = _authStore.currentSchoolId;
      final filter = schoolId != null ? 'school="$schoolId"' : '';
      final records = await _pb
          .collection(Collections.classes)
          .getFullList(filter: filter);
      _classes.value = records.map((r) => ClassGroup.fromRecord(r)).toList();
      return true;
    } catch (e) {
      debugPrint('ClassesStore: Error fetching classes: $e');
      return false;
    } finally {
      _loading.value = false;
    }
  }

  Future<ClassGroup?> getClass(String id) async {
    try {
      final record = await _pb.collection(Collections.classes).getOne(id);
      return ClassGroup.fromRecord(record);
    } catch (e) {
      debugPrint('ClassesStore: Error fetching class: $e');
      return null;
    }
  }

  Future<bool> createClass(Map<String, dynamic> data) async {
    try {
      final record = await _pb
          .collection(Collections.classes)
          .create(body: data);
      _classes.value = [..._classes.value, ClassGroup.fromRecord(record)];
      return true;
    } catch (e) {
      debugPrint('ClassesStore: Error creating class: $e');
      return false;
    }
  }

  Future<bool> updateClass(String id, Map<String, dynamic> data) async {
    try {
      final record = await _pb
          .collection(Collections.classes)
          .update(id, body: data);
      final updated = ClassGroup.fromRecord(record);
      _classes.value =
          _classes.value.map((c) => c.id == id ? updated : c).toList();
      return true;
    } catch (e) {
      debugPrint('ClassesStore: Error updating class: $e');
      return false;
    }
  }

  Future<bool> removeClass(String id) async {
    try {
      await _pb.collection(Collections.classes).delete(id);
      _classes.value = _classes.value.where((c) => c.id != id).toList();
      return true;
    } catch (e) {
      debugPrint('ClassesStore: Error deleting class: $e');
      return false;
    }
  }
}
