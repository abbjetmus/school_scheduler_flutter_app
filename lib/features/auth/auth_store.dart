import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:url_launcher/url_launcher.dart';

class _AuthNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

/// Den inloggade på bibliotekets dator — en lärare eller admin.
class AppUser {
  AppUser({required this.id, required this.name, required this.email, required this.schoolId, required this.roles});

  final String id;
  final String name;
  final String email;
  final String schoolId;
  final List<String> roles;

  bool get canRunLibrary => roles.contains('teacher') || roles.contains('admin');

  factory AppUser.fromRecord(RecordModel record) {
    final name = record.getStringValue('name');
    return AppUser(
      id: record.id,
      name: name.isNotEmpty ? name : record.getStringValue('email'),
      email: record.getStringValue('email'),
      schoolId: record.getStringValue('school'),
      roles: record.getListValue<String>('roles'),
    );
  }
}

/// Inloggning med Microsoft eller Google — samma konton som i webben
/// (Skolpunkten har inga lösenord). PocketBase öppnar leverantören i
/// webbläsaren och appen väntar på svaret via realtime.
///
/// Bara lärare och admin kan köra biblioteket: datorn lånar ut åt vem som
/// helst i skolan, och det får bara lärarkonton göra (/api/library/loans).
class AuthStore {
  AuthStore(this._pb) {
    _sync();
    _pb.authStore.onChange.listen((_) => _sync());
  }

  final PocketBase _pb;
  final _user = ref<AppUser?>(null);
  final _schoolName = ref<String>('');
  final _maxRenewals = ref<int>(2);
  final _signingIn = ref<String?>(null);
  Timer? _refreshTimer;

  /// Ändras vid in- och utloggning — routern lyssnar på den.
  final _authChanges = _AuthNotifier();
  Listenable get authChanges => _authChanges;

  Ref<AppUser?> get user => _user;
  Ref<String> get schoolName => _schoolName;

  /// Hur många gånger ett lån får förlängas på skolan (0 = inte alls).
  /// Samma som maxRenewals i PocketBase; servern avgör till sist.
  Ref<int> get maxRenewals => _maxRenewals;

  /// 'microsoft' eller 'google' medan inloggningen pågår.
  Ref<String?> get signingIn => _signingIn;

  bool get isAuthenticated => _pb.authStore.isValid && (_user.value?.canRunLibrary ?? false);

  void _sync() {
    final record = _pb.authStore.record;
    final next = _pb.authStore.isValid && record != null ? AppUser.fromRecord(record) : null;
    final changed = next?.id != _user.value?.id;
    _user.value = next;
    if (next != null && changed) unawaited(_loadSchool(next.schoolId));
    if (next == null) _schoolName.value = '';
    _authChanges.notify();
  }

  Future<void> _loadSchool(String id) async {
    if (id.isEmpty) return;
    try {
      final school = await _pb.collection('schools').getOne(
            id,
            fields: 'name,libraryRenewalsOff,libraryMaxRenewals',
          );
      _schoolName.value = school.getStringValue('name');
      final max = school.getIntValue('libraryMaxRenewals');
      _maxRenewals.value = school.getBoolValue('libraryRenewalsOff') ? 0 : (max > 0 ? max : 2);
    } catch (_) {}
  }

  /// Förnyar inloggningen vid start och sedan var sjätte timme, så att en
  /// dator som står på i veckor inte loggas ut mitt i en utlåning.
  Future<void> startSession() async {
    _refreshTimer?.cancel();
    await refresh();
    _refreshTimer = Timer.periodic(const Duration(hours: 6), (_) => refresh());
  }

  Future<void> refresh() async {
    if (!_pb.authStore.isValid) return;
    try {
      await _pb.collection('users').authRefresh();
    } on ClientException catch (e) {
      // 401/403 = kontot finns inte längre eller har spärrats. Nätverksfel
      // (0) loggar inte ut — det är bara att försöka igen senare.
      if (e.statusCode == 401 || e.statusCode == 403 || e.statusCode == 404) signOut();
    }
  }

  /// Loggar in. Returnerar ett felmeddelande, eller null om det gick bra.
  Future<String?> signIn(String provider) async {
    _signingIn.value = provider;
    try {
      // Stängs webbläsaren utan att inloggningen slutförs kommer inget svar —
      // ge upp efter tre minuter så att knapparna går att använda igen.
      await _pb.collection('users').authWithOAuth2(provider, (url) async {
        if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
          throw Exception('Kunde inte öppna webbläsaren.');
        }
      }).timeout(const Duration(minutes: 3));
      final user = _user.value;
      if (user == null) return 'Inloggningen misslyckades. Försök igen.';
      if (user.schoolId.isEmpty) {
        signOut();
        return 'Kontot är inte kopplat till någon skola i Skolpunkten.';
      }
      if (!user.canRunLibrary) {
        signOut();
        return 'Bibliotekets dator körs med ett lärar- eller adminkonto. Elever lånar genom att blippa sitt kort här, eller i Skolpunkten på webben.';
      }
      unawaited(startSession());
      return null;
    } on ClientException catch (e) {
      final message = e.response['message'];
      debugPrint('Inloggning: $e');
      if (message is String && message.contains('NOT_ALLOWED:')) {
        return message.split('NOT_ALLOWED:').last.trim();
      }
      if (e.isAbort) return 'Inloggningen avbröts.';
      return 'Inloggningen misslyckades. Försök igen om en stund.';
    } on TimeoutException {
      return 'Inloggningen tog för lång tid. Försök igen.';
    } catch (e) {
      debugPrint('Inloggning: $e');
      return 'Inloggningen misslyckades: $e';
    } finally {
      _signingIn.value = null;
    }
  }

  void signOut() {
    _refreshTimer?.cancel();
    _pb.authStore.clear();
  }
}
