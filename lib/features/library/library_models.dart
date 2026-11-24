import 'package:pocketbase/pocketbase.dart';

/// Bibliotekets data — samma form som svaren från /api/library/* i
/// school-scheduler-pb (pb_hooks/utils/library.js) och som
/// school-scheduler-nuxt-app/app/types/library.ts. Ändras formatet där måste
/// det ändras här också.

String _s(Object? v) => v == null ? '' : v.toString();

Map<String, dynamic> _map(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : const <String, dynamic>{};

/// PocketBase-datum ("2026-11-24 10:15:00.000Z") som lokal tid.
DateTime? parsePbDate(String value) {
  if (value.isEmpty) return null;
  return DateTime.tryParse(value.replaceFirst(' ', 'T'))?.toLocal();
}

class LibraryPerson {
  LibraryPerson({
    required this.id,
    required this.name,
    this.email = '',
    this.className = '',
    this.roles = const [],
    this.protectedIdentity = false,
  });

  final String id;
  final String name;
  final String email;
  final String className;
  final List<String> roles;
  final bool protectedIdentity;

  bool get isStudent => roles.contains('student');

  factory LibraryPerson.fromJson(Map<String, dynamic> json) {
    final name = _s(json['name']);
    final cls = json['className'] ?? _map(_map(json['expand'])['class'])['name'];
    return LibraryPerson(
      id: _s(json['id']),
      name: name.isNotEmpty ? name : _s(json['email']),
      email: _s(json['email']),
      className: _s(cls),
      roles: (json['roles'] as List?)?.map(_s).toList() ?? const [],
      protectedIdentity: json['protectedIdentity'] == true,
    );
  }

  factory LibraryPerson.fromRecord(RecordModel record) => LibraryPerson.fromJson(record.toJson());

  /// "Elev · TE23" — under namnet i listor.
  String get description {
    const labels = {'student': 'Elev', 'teacher': 'Lärare', 'admin': 'Admin'};
    final role = roles.isEmpty ? '' : (labels[roles.first] ?? roles.first);
    return [role, className].where((s) => s.isNotEmpty).join(' · ');
  }
}

class LibraryTitle {
  LibraryTitle({
    required this.id,
    required this.title,
    this.author = '',
    this.isbn = '',
    this.edition = '',
    this.publisher = '',
    this.tags = const [],
    this.coverUrl = '',
  });

  final String id;
  final String title;
  final String author;
  final String isbn;
  final String edition;
  final String publisher;
  final List<String> tags;
  final String coverUrl;

  factory LibraryTitle.fromJson(Map<String, dynamic> json) => LibraryTitle(
        id: _s(json['id']),
        title: _s(json['title']),
        author: _s(json['author']),
        isbn: _s(json['isbn']),
        edition: _s(json['edition']),
        publisher: _s(json['publisher']),
        tags: (json['tags'] as List?)?.map(_s).toList() ?? const [],
        coverUrl: _s(json['coverUrl']),
      );

  factory LibraryTitle.fromRecord(RecordModel record) => LibraryTitle.fromJson(record.toJson());
}

enum CopyStatus { available, loaned, missing, withdrawn }

class LibraryCopy {
  LibraryCopy({
    required this.id,
    required this.titleId,
    this.barcode = '',
    this.rfid = '',
    this.location = '',
    this.note = '',
    this.status = '',
    this.currentLoan = '',
    this.borrowerName = '',
    this.dueAt,
  });

  final String id;
  final String titleId;
  final String barcode;
  final String rfid;
  final String location;
  final String note;

  /// '' | 'missing' | 'withdrawn'
  final String status;
  final String currentLoan;

  /// Bara när exemplaret hämtats med expand currentLoan.borrower.
  final String borrowerName;
  final DateTime? dueAt;

  CopyStatus get state {
    if (status == 'withdrawn') return CopyStatus.withdrawn;
    if (status == 'missing') return CopyStatus.missing;
    return currentLoan.isNotEmpty ? CopyStatus.loaned : CopyStatus.available;
  }

  factory LibraryCopy.fromJson(Map<String, dynamic> json) {
    final loan = _map(_map(json['expand'])['currentLoan']);
    final borrower = _map(_map(loan['expand'])['borrower']);
    return LibraryCopy(
      id: _s(json['id']),
      titleId: _s(json['title']),
      barcode: _s(json['barcode']),
      rfid: _s(json['rfid']),
      location: _s(json['location']),
      note: _s(json['note']),
      status: _s(json['status']),
      currentLoan: _s(json['currentLoan']),
      borrowerName: borrower.isEmpty ? '' : (_s(borrower['name']).isNotEmpty ? _s(borrower['name']) : _s(borrower['email'])),
      dueAt: parsePbDate(_s(loan['dueAt'])),
    );
  }

  factory LibraryCopy.fromRecord(RecordModel record) => LibraryCopy.fromJson(record.toJson());
}

class LibraryLoan {
  LibraryLoan({
    required this.id,
    this.copy,
    this.title,
    this.borrower,
    this.loanedAt,
    this.dueAt,
    this.returnedAt,
    this.source = '',
    this.renewals = 0,
  });

  final String id;
  final LibraryCopy? copy;
  final LibraryTitle? title;
  final LibraryPerson? borrower;
  final DateTime? loanedAt;
  final DateTime? dueAt;
  final DateTime? returnedAt;
  final String source;

  /// Antal gånger lånet förlängts.
  final int renewals;

  bool get isOverdue => returnedAt == null && dueAt != null && dueAt!.isBefore(DateTime.now());

  /// Förläng visas när det är högst en vecka kvar (eller lånet är försenat) —
  /// en förlängning direkt efter lånet ändrar inget. Servern avgör till sist.
  bool canRenew(int maxRenewals) =>
      returnedAt == null &&
      renewals < maxRenewals &&
      (dueAt == null || dueAt!.difference(DateTime.now()).inDays <= 7);

  /// Svar från /api/library/*.
  factory LibraryLoan.fromJson(Map<String, dynamic> json) => LibraryLoan(
        id: _s(json['id']),
        copy: json['copy'] is Map ? LibraryCopy.fromJson(_map(json['copy'])) : null,
        title: json['title'] is Map ? LibraryTitle.fromJson(_map(json['title'])) : null,
        borrower: json['borrower'] is Map ? LibraryPerson.fromJson(_map(json['borrower'])) : null,
        loanedAt: parsePbDate(_s(json['loanedAt'])),
        dueAt: parsePbDate(_s(json['dueAt'])),
        returnedAt: parsePbDate(_s(json['returnedAt'])),
        source: _s(json['source']),
        renewals: (json['renewals'] as num?)?.toInt() ?? 0,
      );

  /// En libraryLoans-post hämtad med expand "copy.title,borrower".
  factory LibraryLoan.fromRecord(RecordModel record) {
    final json = record.toJson();
    final expand = _map(json['expand']);
    final copy = _map(expand['copy']);
    final title = _map(_map(copy['expand'])['title']);
    final borrower = _map(expand['borrower']);
    return LibraryLoan(
      id: _s(json['id']),
      copy: copy.isEmpty ? null : LibraryCopy.fromJson(copy),
      title: title.isEmpty ? null : LibraryTitle.fromJson(title),
      borrower: borrower.isEmpty ? null : LibraryPerson.fromJson(borrower),
      loanedAt: parsePbDate(_s(json['loanedAt'])),
      dueAt: parsePbDate(_s(json['dueAt'])),
      returnedAt: parsePbDate(_s(json['returnedAt'])),
      source: _s(json['source']),
      renewals: (json['renewals'] as num?)?.toInt() ?? 0,
    );
  }
}

/// QR-kod för lån med mobilen — /api/library/kiosk-sessions.
/// status: open, used (lånad med koden), expired, unavailable (lånad på annat sätt).
class KioskSessionInfo {
  KioskSessionInfo({required this.token, required this.url, required this.status, this.expiresAt, this.loan});

  final String token;
  final String url;
  final String status;
  final DateTime? expiresAt;
  final LibraryLoan? loan;

  factory KioskSessionInfo.fromJson(Map<String, dynamic> json) => KioskSessionInfo(
        token: _s(json['token']),
        url: _s(json['url']),
        status: _s(json['status']),
        expiresAt: parsePbDate(_s(json['expiresAt'])),
        loan: json['loan'] is Map ? LibraryLoan.fromJson(_map(json['loan'])) : null,
      );
}

/// Vad en blippad eller skannad kod är — GET /api/library/scan.
sealed class ScanResult {
  const ScanResult(this.code);
  final String code;

  factory ScanResult.fromJson(Map<String, dynamic> json) {
    final code = _s(json['code']);
    switch (json['type']) {
      case 'copy':
        return ScannedCopy(
          code,
          copy: LibraryCopy.fromJson(_map(json['copy'])),
          title: LibraryTitle.fromJson(_map(json['title'])),
          loan: json['loan'] is Map ? LibraryLoan.fromJson(_map(json['loan'])) : null,
        );
      case 'user':
        return ScannedCard(
          code,
          person: LibraryPerson.fromJson(_map(json['user'])),
          loans: (json['loans'] as List? ?? const []).map((l) => LibraryLoan.fromJson(_map(l))).toList(),
        );
      case 'title':
        return ScannedIsbn(
          code,
          title: LibraryTitle.fromJson(_map(json['title'])),
          copies: (json['copies'] as List? ?? const []).map((c) => LibraryCopy.fromJson(_map(c))).toList(),
        );
      default:
        return ScannedUnknown(code, isbn: _s(json['isbn']));
    }
  }
}

class ScannedCopy extends ScanResult {
  const ScannedCopy(super.code, {required this.copy, required this.title, this.loan});
  final LibraryCopy copy;
  final LibraryTitle title;
  final LibraryLoan? loan;
}

class ScannedCard extends ScanResult {
  const ScannedCard(super.code, {required this.person, required this.loans});
  final LibraryPerson person;
  final List<LibraryLoan> loans;
}

class ScannedIsbn extends ScanResult {
  const ScannedIsbn(super.code, {required this.title, required this.copies});
  final LibraryTitle title;
  final List<LibraryCopy> copies;
}

class ScannedUnknown extends ScanResult {
  const ScannedUnknown(super.code, {this.isbn = ''});
  final String isbn;
}

/// "04:a1 b2" → "04A1B2" — samma som normalizeCode i PocketBase.
String normalizeLibraryCode(String value) {
  final s = value.trim().toUpperCase().replaceAll(RegExp(r'[\s:\-]'), '');
  return s.length > 64 ? s.substring(0, 64) : s;
}
