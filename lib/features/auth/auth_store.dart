import 'package:flutter/foundation.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/models/pocketbase_types.dart';

class AuthStore {
  final PocketBase _pb;

  AuthStore(this._pb) {
    _initialize();
  }

  final _currentUser = ref<User?>(null);
  final _loading = ref<bool>(false);

  late final _isAuthenticated = computed(() => _currentUser.value != null);

  Ref<User?> get currentUser => _currentUser;
  Ref<bool> get loading => _loading;
  ReadonlyRef<bool> get isAuthenticated => _isAuthenticated;

  String? get currentSchoolId => _currentUser.value?.schoolId;

  void _initialize() {
    // Listen to PocketBase auth changes and sync to reactive refs
    _pb.authStore.onChange.listen((event) {
      if (_pb.authStore.isValid) {
        final record = _pb.authStore.record;
        if (record != null) {
          _currentUser.value = User.fromRecord(record);
        }
      } else {
        _currentUser.value = null;
      }
    });

    // Initialize current user if already authenticated
    if (_pb.authStore.isValid && _pb.authStore.record != null) {
      _currentUser.value = User.fromRecord(_pb.authStore.record!);
    }
  }

  /// Sign in with Microsoft OAuth2
  Future<bool> signInWithMicrosoft() async {
    _loading.value = true;

    try {
      debugPrint('=== Starting Microsoft OAuth2 flow ===');

      // Authenticate with Microsoft OAuth2
      // PocketBase handles the OAuth flow and token exchange
      final authData = await _pb.collection(Collections.users).authWithOAuth2(
        'microsoft',
        // URL callback to open the OAuth URL in browser
        (url) async {
          debugPrint('OAuth URL received from PocketBase:');
          debugPrint('  Full URL: $url');
          debugPrint('  Host: ${url.host}');
          debugPrint('  Path: ${url.path}');
          debugPrint('  Query params: ${url.queryParameters}');

          // Open the OAuth URL in the system browser
          if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
            throw Exception('Could not launch OAuth URL: $url');
          }

          debugPrint('Browser opened successfully, waiting for OAuth callback...');
        },
      );

      debugPrint('=== OAuth2 flow completed successfully ===');
      debugPrint('User authenticated: ${authData.record.id}');
      _currentUser.value = User.fromRecord(authData.record);
      return true;
    } catch (e, stackTrace) {
      debugPrint('=== Microsoft OAuth2 ERROR ===');
      debugPrint('Error type: ${e.runtimeType}');
      debugPrint('Error message: $e');
      debugPrint('Stack trace: $stackTrace');

      // Try to extract more details from ClientException
      if (e.toString().contains('ClientException')) {
        debugPrint('This is a PocketBase client error - check:');
        debugPrint('  1. Client Secret in PocketBase');
        debugPrint('  2. Token URL in PocketBase');
        debugPrint('  3. User API URL in PocketBase');
        debugPrint('  4. Azure redirect URI matches PocketBase');
      }

      rethrow;
    } finally {
      _loading.value = false;
    }
  }

  // Email/password authentication (commented out for now)
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
