import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart';
import '../../core/models/pocketbase_types.dart';
import '../auth/auth_store.dart' as app_auth;

class UsersStore {
  final PocketBase _pb;
  final app_auth.AuthStore _authStore;

  UsersStore(this._pb, this._authStore);

  final _users = ref<List<User>>([]);
  final _loading = ref<bool>(false);

  Ref<List<User>> get users => _users;
  Ref<bool> get loading => _loading;

  Future<bool> getUsers({String? schoolId}) async {
    _loading.value = true;
    try {
      final filter = schoolId != null ? 'school="$schoolId"' : '';
      final records = await _pb
          .collection(Collections.users)
          .getFullList(filter: filter, sort: 'name');
      _users.value = records.map((r) => User.fromRecord(r)).toList();
      return true;
    } catch (e) {
      debugPrint('UsersStore: Error fetching users: $e');
      return false;
    } finally {
      _loading.value = false;
    }
  }

  Future<bool> createUser(Map<String, dynamic> data) async {
    try {
      final schoolId = _authStore.currentSchoolId;
      final password = data['password'] as String? ?? generateTemporaryPassword();
      final body = {
        ...data,
        'emailVisibility': true,
        'password': password,
        'passwordConfirm': password,
        'school': schoolId,
      };
      final record = await _pb.collection(Collections.users).create(body: body);
      _users.value = [..._users.value, User.fromRecord(record)];
      return true;
    } catch (e) {
      debugPrint('UsersStore: Error creating user: $e');
      return false;
    }
  }

  Future<bool> updateUser(String id, Map<String, dynamic> data) async {
    try {
      final record = await _pb.collection(Collections.users).update(id, body: data);
      final updated = User.fromRecord(record);
      _users.value = _users.value.map((u) => u.id == id ? updated : u).toList();
      return true;
    } catch (e) {
      debugPrint('UsersStore: Error updating user: $e');
      return false;
    }
  }

  Future<bool> removeUser(String id) async {
    try {
      await _pb.collection(Collections.users).delete(id);
      _users.value = _users.value.where((u) => u.id != id).toList();
      return true;
    } catch (e) {
      debugPrint('UsersStore: Error deleting user: $e');
      return false;
    }
  }

  Future<bool> createAllowedUser(Map<String, dynamic> data) async {
    try {
      final schoolId = _authStore.currentSchoolId;
      if (schoolId == null) return false;
      await _pb.collection(Collections.allowedUsers).create(body: {
        ...data,
        'school': schoolId,
      });
      return true;
    } catch (e) {
      debugPrint('UsersStore: Error creating allowed user: $e');
      return false;
    }
  }

  String generateTemporaryPassword() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return List.generate(24, (_) => chars[random.nextInt(chars.length)]).join();
  }
}
