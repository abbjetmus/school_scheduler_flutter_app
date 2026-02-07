import 'package:flutter/foundation.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart';
import '../../core/models/pocketbase_types.dart';
import '../auth/auth_store.dart' as app_auth;

class StudentsStore {
  final PocketBase _pb;
  final app_auth.AuthStore _authStore;

  StudentsStore(this._pb, this._authStore);

  final _students = ref<List<Student>>([]);
  final _loading = ref<bool>(false);

  Ref<List<Student>> get students => _students;
  Ref<bool> get loading => _loading;

  Future<bool> getStudents() async {
    _loading.value = true;
    try {
      final schoolId = _authStore.currentSchoolId;
      final filter = schoolId != null ? 'class.school="$schoolId"' : '';
      final records = await _pb
          .collection(Collections.students)
          .getFullList(filter: filter);
      _students.value = records.map((r) => Student.fromRecord(r)).toList();
      return true;
    } catch (e) {
      debugPrint('StudentsStore: Error fetching students: $e');
      return false;
    } finally {
      _loading.value = false;
    }
  }

  Future<({List<Student> items, int totalPages, int totalItems})>
  getStudentsPaginated({
    int page = 1,
    int perPage = 50,
    String? search,
  }) async {
    try {
      final schoolId = _authStore.currentSchoolId;
      var filter = schoolId != null ? 'class.school="$schoolId"' : '';

      if (search != null && search.trim().isNotEmpty) {
        final searchFilter =
            '(name ~ "$search" || email ~ "$search" || cardId ~ "$search")';
        filter =
            filter.isNotEmpty ? '($filter) && $searchFilter' : searchFilter;
      }

      final result = await _pb
          .collection(Collections.students)
          .getList(page: page, perPage: perPage, filter: filter, sort: 'name');

      final items = result.items.map((r) => Student.fromRecord(r)).toList();
      return (
        items: items,
        totalPages: result.totalPages,
        totalItems: result.totalItems,
      );
    } catch (e) {
      debugPrint('StudentsStore: Error fetching paginated students: $e');
      return (items: <Student>[], totalPages: 0, totalItems: 0);
    }
  }

  Future<bool> createStudent(Map<String, dynamic> data) async {
    try {
      final record = await _pb
          .collection(Collections.students)
          .create(body: data);
      _students.value = [..._students.value, Student.fromRecord(record)];
      return true;
    } catch (e) {
      debugPrint('StudentsStore: Error creating student: $e');
      return false;
    }
  }

  Future<bool> updateStudent(String id, Map<String, dynamic> data) async {
    try {
      final record = await _pb
          .collection(Collections.students)
          .update(id, body: data);
      final updated = Student.fromRecord(record);
      _students.value =
          _students.value.map((s) => s.id == id ? updated : s).toList();
      return true;
    } catch (e) {
      debugPrint('StudentsStore: Error updating student: $e');
      return false;
    }
  }

  Future<bool> removeStudent(String id) async {
    try {
      await _pb.collection(Collections.students).delete(id);
      _students.value = _students.value.where((s) => s.id != id).toList();
      return true;
    } catch (e) {
      debugPrint('StudentsStore: Error deleting student: $e');
      return false;
    }
  }

  Future<bool> updateStudentHaldorIdByEmail(
    String email,
    String classId,
    String haldorStudentId,
  ) async {
    try {
      final students = await _pb
          .collection(Collections.students)
          .getFullList(filter: 'email = "$email" && class = "$classId"');
      if (students.isEmpty) return false;

      final student = students.first;
      await _pb
          .collection(Collections.students)
          .update(student.id, body: {'haldorStudentId': haldorStudentId});

      final index = _students.value.indexWhere((s) => s.id == student.id);
      if (index != -1) {
        await getStudents();
      }
      return true;
    } catch (e) {
      debugPrint('StudentsStore: Error updating Haldor ID: $e');
      return false;
    }
  }
}
