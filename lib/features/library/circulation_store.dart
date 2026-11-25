import 'dart:async';

import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:intl/intl.dart';

import '../reader/reader_hub.dart';
import 'library_api.dart';
import 'library_models.dart';

enum EventKind { lent, returned, card, info, error }

class CirculationEvent {
  CirculationEvent(this.kind, this.title, [this.detail = '']) : time = DateTime.now();
  final EventKind kind;
  final String title;
  final String detail;
  final DateTime time;
}

/// En bok som har blippats men väntar på en låntagare.
class PendingCopy {
  PendingCopy({
    required this.copyId,
    required this.title,
    required this.location,
    required this.deadline,
    this.token,
    this.qrUrl,
  });
  final String copyId;
  final String title;
  final String location;

  /// När boken slutar vänta (QR-kodens giltighet).
  final DateTime deadline;

  /// QR-koden eleven skannar med mobilen (null om den inte gick att skapa).
  final String? token;
  final String? qrUrl;
}

final _date = DateFormat('d MMMM', 'sv');
String formatDue(DateTime? date) => date == null ? '' : _date.format(date);

/// Utlåningen vid bibliotekets dator.
///
/// Flödet är byggt för att man bara ska behöva blippa:
///  - Ett **passerkort** (kopplat under Kort/Blipp) gör personen till låntagare. Personens lån visas.
///  - En **bok som är utlånad** lämnas tillbaka — oavsett vem som har den.
///  - En **bok som finns** lånas ut till låntagaren. Finns ingen låntagare
///    visas en QR-kod: eleven skannar den med mobilen (inloggad i Skolpunkten)
///    och lånar där. Koden gäller två minuter och bara här, så lånet görs på
///    plats. Ett passerkort som blippas under tiden lånar direkt i stället.
///  - Ett **ISBN** (bokens streckkod, för böcker utan egen etikett) fungerar
///    som en bok: första lediga exemplaret lånas ut, och har låntagaren boken
///    lämnas den tillbaka.
/// Efter [ReaderHub.sessionTimeoutSeconds] utan aktivitet släpps låntagaren,
/// så att nästa elev inte lånar på förra elevens kort.
class CirculationStore {
  CirculationStore(this._api, this._hub);

  final LibraryApi _api;
  final ReaderHub _hub;

  final borrower = ref<LibraryPerson?>(null);
  final borrowerLoans = ref<List<LibraryLoan>>([]);
  final pending = ref<PendingCopy?>(null);
  final events = ref<List<CirculationEvent>>([]);
  final busy = ref(false);

  /// Sekunder kvar innan låntagaren släpps (null = ingen låntagare).
  final secondsLeft = ref<int?>(null);

  Timer? _timer;
  Timer? _poll;
  bool _checking = false;
  final _queue = <String>[];

  CirculationEvent? get latest => events.value.isEmpty ? null : events.value.first;

  void _log(EventKind kind, String title, [String detail = '']) {
    final list = [CirculationEvent(kind, title, detail), ...events.value];
    events.value = list.length > 40 ? list.sublist(0, 40) : list;
    switch (kind) {
      case EventKind.lent:
      case EventKind.returned:
        _hub.playSuccess();
      case EventKind.card:
        _hub.playCard();
      case EventKind.error:
        _hub.playError();
      case EventKind.info:
        break;
    }
  }

  // ── Session ───────────────────────────────────────────────────────────

  /// Låntagarens nedräkning. En bok som väntar på QR-lån utan låntagare
  /// hanteras av [_checkPending] (koden har egen giltighetstid).
  void _touch() {
    _timer?.cancel();
    if (borrower.value == null) {
      secondsLeft.value = null;
      return;
    }
    secondsLeft.value = _hub.sessionTimeoutSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      final left = (secondsLeft.value ?? 0) - 1;
      if (left <= 0) {
        endSession();
      } else {
        secondsLeft.value = left;
      }
    });
  }

  void endSession() {
    _timer?.cancel();
    _poll?.cancel();
    borrower.value = null;
    borrowerLoans.value = [];
    pending.value = null;
    secondsLeft.value = null;
  }

  Future<void> _reloadBorrowerLoans() async {
    final person = borrower.value;
    if (person == null) return;
    try {
      borrowerLoans.value = await _api.loans(overdueOnly: false, borrower: person.id);
    } catch (_) {}
  }

  /// Låntagaren valdes i listan i stället för med kort.
  Future<void> selectBorrower(LibraryPerson person) async {
    borrower.value = person;
    borrowerLoans.value = [];
    _touch();
    _log(EventKind.card, 'Låntagare: ${person.name}', 'Blippa böckerna som ska lånas.');
    await _reloadBorrowerLoans();
    await _lendPending();
  }

  void cancelPending() {
    _poll?.cancel();
    pending.value = null;
    _touch();
  }

  /// Följer QR-koden: lånad med mobilen, utgången eller lånad på annat sätt.
  Future<void> _checkPending() async {
    final p = pending.value;
    if (p == null) {
      _poll?.cancel();
      return;
    }
    if (_checking) return;
    _checking = true;
    try {
      final token = p.token;
      if (token == null) {
        if (DateTime.now().isAfter(p.deadline)) {
          _poll?.cancel();
          pending.value = null;
        }
        return;
      }
      final session = await _api.kioskSession(token);
      if (pending.value?.token != token) return;
      switch (session.status) {
        case 'used':
          _poll?.cancel();
          pending.value = null;
          final loan = session.loan;
          _log(
            EventKind.lent,
            '${p.title} är utlånad',
            'Till ${loan?.borrower?.name ?? 'dig'}. Lämnas tillbaka senast ${formatDue(loan?.dueAt)}.',
          );
        case 'expired':
          _poll?.cancel();
          pending.value = null;
          _log(EventKind.info, 'QR-koden gick ut', 'Blippa ${p.title} igen om du vill låna den.');
        case 'unavailable':
          _poll?.cancel();
          pending.value = null;
      }
    } on LibraryException {
      // Tillfälligt nätfel — försök igen vid nästa tick.
    } finally {
      _checking = false;
    }
  }

  // ── Koder ─────────────────────────────────────────────────────────────

  /// En kod från läsaren. Koder som kommer medan en annan behandlas köas, så
  /// att en hög böcker kan blippas i snabb takt.
  Future<void> handleCode(String code) async {
    _queue.add(code);
    if (busy.value) return;
    busy.value = true;
    try {
      while (_queue.isNotEmpty) {
        await _process(_queue.removeAt(0));
      }
    } finally {
      busy.value = false;
    }
  }

  Future<void> _process(String code) async {
    try {
      final result = await _api.scan(code);
      switch (result) {
        case ScannedCard(:final person, :final loans):
          borrower.value = person;
          borrowerLoans.value = loans;
          _touch();
          final overdue = loans.where((l) => l.isOverdue).length;
          _log(
            EventKind.card,
            'Hej ${person.name.split(' ').first}!',
            overdue > 0
                ? 'Du har $overdue ${overdue == 1 ? 'försenad bok' : 'försenade böcker'}. Blippa böckerna du vill låna eller lämna tillbaka.'
                : 'Blippa böckerna du vill låna eller lämna tillbaka.',
          );
          await _lendPending();
        case ScannedCopy(:final copy, :final title, :final loan):
          if (loan != null) {
            await _return(copy.id, title.title, copy.location);
          } else if (copy.status == 'missing' || copy.status == 'withdrawn') {
            _log(
              EventKind.error,
              '${title.title} kan inte lånas',
              copy.status == 'missing'
                  ? 'Exemplaret är markerat som saknat. Ändra det i Skolpunkten under Bibliotek → Böcker.'
                  : 'Exemplaret är gallrat.',
            );
          } else {
            await _lendOrWait(copy.id, title.title, copy.location);
          }
        case ScannedIsbn(:final title, :final copies):
          final mine = borrowerLoans.value.where((l) => l.title?.id == title.id).firstOrNull;
          if (mine != null) {
            await _returnLoan(mine.id, title.title, mine.copy?.location ?? '');
            break;
          }
          final free = copies.where((c) => c.state == CopyStatus.available).firstOrNull;
          if (free != null) {
            await _lendOrWait(free.id, title.title, free.location);
          } else {
            _log(
              EventKind.error,
              'Alla exemplar av ${title.title} är utlånade',
              'Ska boken lämnas tillbaka? Blippa passerkortet först, eller blippa bokens RFID-etikett.',
            );
          }
        case ScannedUnknown(:final isbn):
          _log(
            EventKind.error,
            isbn.isNotEmpty ? 'Boken finns inte i biblioteket' : 'Okänd kod',
            isbn.isNotEmpty
                ? 'ISBN $isbn är inte inlagt. Bibliotekarien kan lägga in boken under Böcker genom att skanna streckkoden.'
                : 'Koden ${result.code} är inte kopplad till någon bok eller något passerkort. Koppla den under Böcker eller Kort/Blipp.',
          );
      }
    } on LibraryException catch (e) {
      _log(EventKind.error, 'Det gick inte', e.message);
    }
  }

  Future<void> _lendOrWait(String copyId, String title, String location) async {
    if (borrower.value != null) {
      await _lend(copyId);
      return;
    }
    _poll?.cancel();
    try {
      final session = await _api.createKioskSession(copyId);
      pending.value = PendingCopy(
        copyId: copyId,
        title: title,
        location: location,
        deadline: session.expiresAt ?? DateTime.now().add(const Duration(minutes: 2)),
        token: session.token,
        qrUrl: session.url,
      );
      _log(EventKind.info, title, 'Skanna QR-koden med mobilen för att låna boken.');
    } on LibraryException catch (e) {
      // Utan QR-kod går det fortfarande att blippa ett passerkort.
      pending.value = PendingCopy(
        copyId: copyId,
        title: title,
        location: location,
        deadline: DateTime.now().add(Duration(seconds: _hub.sessionTimeoutSeconds)),
      );
      _log(EventKind.error, 'Ingen QR-kod', '${e.message} Blippa ditt passerkort för att låna boken.');
    }
    _poll = Timer.periodic(const Duration(milliseconds: 1500), (_) => _checkPending());
  }

  Future<void> _lendPending() async {
    final p = pending.value;
    if (p == null || borrower.value == null) return;
    _poll?.cancel();
    pending.value = null;
    await _lend(p.copyId);
  }

  Future<void> _lend(String copyId) async {
    final person = borrower.value!;
    try {
      final loan = await _api.lend(copy: copyId, borrower: person.id);
      _log(
        EventKind.lent,
        '${loan.title?.title ?? 'Boken'} är utlånad',
        'Till ${loan.borrower?.name ?? person.name}. Lämnas tillbaka senast ${formatDue(loan.dueAt)}.',
      );
      await _reloadBorrowerLoans();
    } on LibraryException catch (e) {
      _log(EventKind.error, 'Boken kunde inte lånas ut', e.message);
    }
    _touch();
  }

  Future<void> _return(String copyId, String title, String location) async {
    try {
      final loan = await _api.returnBook(copy: copyId);
      _afterReturn(loan, title, location);
    } on LibraryException catch (e) {
      _log(EventKind.error, 'Boken kunde inte lämnas tillbaka', e.message);
    }
  }

  Future<void> _returnLoan(String loanId, String title, String location) async {
    try {
      final loan = await _api.returnBook(loan: loanId);
      _afterReturn(loan, title, location);
    } on LibraryException catch (e) {
      _log(EventKind.error, 'Boken kunde inte lämnas tillbaka', e.message);
    }
  }

  void _afterReturn(LibraryLoan loan, String title, String location) {
    final late = loan.dueAt != null && loan.returnedAt != null && loan.returnedAt!.isAfter(loan.dueAt!);
    _log(
      EventKind.returned,
      '$title är återlämnad',
      [
        if (loan.borrower != null) 'Lånad av ${loan.borrower!.name}${late ? ' (försenad)' : ''}.',
        location.isNotEmpty ? 'Ställ den på $location.' : 'Ställ tillbaka den på hyllan.',
      ].join(' '),
    );
    unawaited(_reloadBorrowerLoans());
    if (borrower.value != null) _touch();
  }

  /// Förlänger ett av låntagarens lån (knappen på låntagarkortet).
  Future<void> renew(LibraryLoan loan) async {
    try {
      final updated = await _api.renew(loan.id);
      _log(
        EventKind.lent,
        '${updated.title?.title ?? loan.title?.title ?? 'Lånet'} är förlängt',
        'Lämnas tillbaka senast ${formatDue(updated.dueAt)}.',
      );
      await _reloadBorrowerLoans();
    } on LibraryException catch (e) {
      _log(EventKind.error, 'Lånet kunde inte förlängas', e.message);
    }
    _touch();
  }

  void dispose() {
    _timer?.cancel();
    _poll?.cancel();
  }
}
