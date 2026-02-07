import 'package:flutter/foundation.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart';
import '../../core/models/pocketbase_types.dart';

class AuthStore {
  final PocketBase _pb;

  AuthStore(this._pb);

  final _currentUser = ref<User?>(null);
  final _loading = ref<bool>(false);

  Ref<User?> get currentUser => _currentUser;
  Ref<bool> get loading => _loading;

  bool get isAuthenticated => _pb.authStore.isValid;

  String? get currentSchoolId => _currentUser.value?.schoolId;

  Future<bool> signIn(String email, String password) async {
    _loading.value = true;
    try {
      final authData = await _pb
          .collection(Collections.users)
          .authWithPassword(email, password);
      _currentUser.value = User.fromRecord(authData.record);
      return true;
    } catch (e) {
      debugPrint('AuthStore: Sign-in error: $e');
      rethrow;
    } finally {
      _loading.value = false;
    }
  }

  Future<bool> signUp(String name, String email, String password) async {
    _loading.value = true;
    try {
      await _pb.collection(Collections.users).create(body: {
        'email': email,
        'emailVisibility': true,
        'password': password,
        'passwordConfirm': password,
        'name': name,
      });
      await _pb.collection(Collections.users).requestVerification(email);
      return true;
    } catch (e) {
      debugPrint('AuthStore: Sign-up error: $e');
      return false;
    } finally {
      _loading.value = false;
    }
  }

  void signOut() {
    _pb.authStore.clear();
    _currentUser.value = null;
  }

  Future<bool> forgotPassword(String email) async {
    try {
      await _pb.collection(Collections.users).requestPasswordReset(email);
      return true;
    } catch (e) {
      debugPrint('AuthStore: Forgot password error: $e');
      return false;
    }
  }

  Future<bool> resetPassword(
    String token,
    String password,
  ) async {
    try {
      await _pb
          .collection(Collections.users)
          .confirmPasswordReset(token, password, password);
      return true;
    } catch (e) {
      debugPrint('AuthStore: Reset password error: $e');
      return false;
    }
  }

  Future<bool> confirmVerification(String token) async {
    try {
      await _pb.collection(Collections.users).confirmVerification(token);
      return true;
    } catch (e) {
      debugPrint('AuthStore: Confirm verification error: $e');
      return false;
    }
  }

  Future<bool> requestVerification(String email) async {
    try {
      await _pb.collection(Collections.users).requestVerification(email);
      return true;
    } catch (e) {
      debugPrint('AuthStore: Request verification error: $e');
      return false;
    }
  }

  Future<bool> getUser() async {
    try {
      final record = _pb.authStore.record;
      if (record == null) return false;
      final user = await _pb.collection(Collections.users).getOne(record.id);
      _currentUser.value = User.fromRecord(user);
      return true;
    } catch (e) {
      debugPrint('AuthStore: Error getting user: $e');
      return false;
    }
  }

  Future<bool> updateUserName(String name) async {
    final userId = _pb.authStore.record?.id;
    if (userId == null) return false;
    try {
      final updated = await _pb
          .collection(Collections.users)
          .update(userId, body: {'name': name});
      _currentUser.value = User.fromRecord(updated);
      return true;
    } catch (e) {
      debugPrint('AuthStore: Error updating user name: $e');
      return false;
    }
  }

  Future<bool> updateUserEmail(String email) async {
    final userId = _pb.authStore.record?.id;
    if (userId == null) return false;
    try {
      final updated = await _pb
          .collection(Collections.users)
          .update(userId, body: {'email': email, 'emailVisibility': true});
      _currentUser.value = User.fromRecord(updated);
      return true;
    } catch (e) {
      debugPrint('AuthStore: Error updating user email: $e');
      return false;
    }
  }

  Future<bool> updateUserPassword({
    required String oldPassword,
    required String password,
    required String passwordConfirm,
  }) async {
    final userId = _pb.authStore.record?.id;
    if (userId == null) return false;
    try {
      final updated = await _pb.collection(Collections.users).update(
        userId,
        body: {
          'oldPassword': oldPassword,
          'password': password,
          'passwordConfirm': passwordConfirm,
        },
      );
      _currentUser.value = User.fromRecord(updated);
      return true;
    } catch (e) {
      debugPrint('AuthStore: Error updating user password: $e');
      return false;
    }
  }

  Future<bool> deleteUser() async {
    final userId = _pb.authStore.record?.id;
    if (userId == null) return false;
    try {
      await _pb.collection(Collections.users).delete(userId);
      signOut();
      return true;
    } catch (e) {
      debugPrint('AuthStore: Error deleting user: $e');
      return false;
    }
  }
}
