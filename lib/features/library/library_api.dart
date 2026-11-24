import 'package:pocketbase/pocketbase.dart';

import 'library_models.dart';

/// Ett fel att visa för bibliotekarien — PocketBase-hookarna skriver
/// begripliga meddelanden på svenska.
class LibraryException implements Exception {
  LibraryException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Bibliotekets anrop mot Skolpunkten (school-scheduler-pb). Utlåning,
/// återlämning, kort och uppslag går via /api/library/*, där reglerna finns;
/// listor läses direkt ur collections. Tjänst utan refs — sidorna och
/// [CirculationStore] håller tillståndet.
class LibraryApi {
  LibraryApi(this._pb);

  final PocketBase _pb;

  String get _school => _pb.authStore.record?.getStringValue('school') ?? '';

  Future<T> _call<T>(Future<T> Function() fn, String fallback) async {
    try {
      return await fn();
    } on ClientException catch (e) {
      throw LibraryException(_message(e, fallback));
    }
  }

  static String _message(ClientException e, String fallback) {
    if (e.statusCode == 0) return 'Ingen kontakt med Skolpunkten. Kontrollera nätverket.';
    final response = e.response;
    final message = response['message'];
    final data = response['data'];
    if (message is String &&
        message.isNotEmpty &&
        !message.startsWith('Failed to') &&
        !message.startsWith('Something went wrong')) {
      return message;
    }
    if (data is Map) {
      for (final value in data.values) {
        if (value is Map && value['message'] is String) return value['message'] as String;
      }
    }
    if (e.statusCode == 401) return 'Du är utloggad. Logga in igen.';
    if (e.statusCode == 403) return 'Du har inte behörighet till det här.';
    return fallback;
  }

  // ── Utlåning ──────────────────────────────────────────────────────────

  Future<ScanResult> scan(String code) => _call(() async {
        final json = await _pb.send<Map<String, dynamic>>('/api/library/scan', query: {'code': code});
        return ScanResult.fromJson(json);
      }, 'Kunde inte läsa koden.');

  /// Låna ut. Ange exemplaret (id eller kod) och låntagaren (id eller kort).
  Future<LibraryLoan> lend({String? copy, String? code, String? borrower, String? cardId}) => _call(() async {
        final json = await _pb.send<Map<String, dynamic>>(
          '/api/library/loans',
          method: 'POST',
          body: {
            'copy': ?copy,
            'code': ?code,
            'borrower': ?borrower,
            'cardId': ?cardId,
            'source': 'kiosk',
          },
        );
        return LibraryLoan.fromJson(json);
      }, 'Kunde inte låna ut boken.');

  /// Förlänger lånet (ny återlämningsdag = i dag + skolans lånetid).
  Future<LibraryLoan> renew(String loanId) => _call(() async {
        final json = await _pb.send<Map<String, dynamic>>(
          '/api/library/renewals',
          method: 'POST',
          body: {'loan': loanId},
        );
        return LibraryLoan.fromJson(json);
      }, 'Kunde inte förlänga lånet.');

  Future<LibraryLoan> returnBook({String? loan, String? copy, String? code}) => _call(() async {
        final json = await _pb.send<Map<String, dynamic>>(
          '/api/library/returns',
          method: 'POST',
          body: {'loan': ?loan, 'copy': ?copy, 'code': ?code},
        );
        return LibraryLoan.fromJson(json);
      }, 'Kunde inte registrera återlämningen.');

  // ── Listor ────────────────────────────────────────────────────────────

  Future<List<LibraryLoan>> loans({required bool overdueOnly, String? borrower}) => _call(() async {
        final parts = [
          _pb.filter('school = {:school} && returnedAt = ""', {'school': _school}),
          if (overdueOnly) 'dueAt < @now',
          if (borrower != null) _pb.filter('borrower = {:b}', {'b': borrower}),
        ];
        final records = await _pb.collection('libraryLoans').getFullList(
              filter: parts.join(' && '),
              sort: 'dueAt',
              expand: 'copy.title,borrower',
            );
        return records.map(LibraryLoan.fromRecord).toList();
      }, 'Kunde inte hämta lånen.');

  Future<List<LibraryTitle>> titles() => _call(() async {
        final records = await _pb.collection('libraryTitles').getFullList(
              filter: _pb.filter('school = {:school}', {'school': _school}),
              sort: 'title',
            );
        return records.map(LibraryTitle.fromRecord).toList();
      }, 'Kunde inte hämta böckerna.');

  Future<List<LibraryCopy>> copies({String? title}) => _call(() async {
        final records = await _pb.collection('libraryCopies').getFullList(
              filter: title != null
                  ? _pb.filter('title = {:title}', {'title': title})
                  : _pb.filter('school = {:school}', {'school': _school}),
              sort: 'location,created',
              expand: 'currentLoan.borrower',
            );
        return records.map(LibraryCopy.fromRecord).toList();
      }, 'Kunde inte hämta exemplaren.');

  /// Sätter RFID-etiketten (eller tar bort den med tom sträng) på ett exemplar.
  Future<LibraryCopy> setCopyRfid(String copyId, String rfid) => _call(() async {
        final record = await _pb.collection('libraryCopies').update(copyId, body: {'rfid': normalizeLibraryCode(rfid)});
        return LibraryCopy.fromRecord(record);
      }, 'Kunde inte spara etiketten.');

  /// Nytt exemplar av en bok, valfritt med RFID-etikett.
  Future<LibraryCopy> addCopy(String titleId, {String location = '', String rfid = ''}) => _call(() async {
        final record = await _pb.collection('libraryCopies').create(body: {
          'title': titleId,
          'school': _school,
          'location': location,
          'rfid': normalizeLibraryCode(rfid),
        });
        return LibraryCopy.fromRecord(record);
      }, 'Kunde inte lägga till exemplaret.');

  // ── Personer och kort ─────────────────────────────────────────────────

  Future<List<LibraryPerson>> searchPeople(String query) => _call(() async {
        final result = await _pb.collection('users').getList(
              perPage: 20,
              filter: _pb.filter(
                'school = {:school} && (name ~ {:q} || email ~ {:q})',
                {'school': _school, 'q': query.trim()},
              ),
              sort: 'name',
              expand: 'class',
            );
        return result.items.map(LibraryPerson.fromRecord).toList();
      }, 'Kunde inte söka.');

  /// Kopplar kortet till personen; tomt kort tar bort kopplingen.
  Future<void> setCard(String userId, String cardId) => _call(
        () => _pb.send('/api/library/cards', method: 'POST', body: {'user': userId, 'cardId': cardId}),
        'Kunde inte koppla kortet.',
      );

  /// Personer med kort, med kortets id.
  Future<List<(LibraryPerson, String)>> cards() => _call(() async {
        final records = await _pb.collection('userCards').getFullList(
              filter: _pb.filter('school = {:school}', {'school': _school}),
              expand: 'user',
            );
        final list = <(LibraryPerson, String)>[];
        for (final r in records) {
          final user = r.toJson()['expand']?['user'];
          if (user is Map) {
            list.add((LibraryPerson.fromJson(Map<String, dynamic>.from(user)), r.getStringValue('cardId')));
          }
        }
        list.sort((a, b) => a.$1.name.toLowerCase().compareTo(b.$1.name.toLowerCase()));
        return list;
      }, 'Kunde inte hämta korten.');
}
