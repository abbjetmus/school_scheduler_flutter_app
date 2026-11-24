import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:intl/intl.dart';

import '../../../core/di/injection_keys.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui.dart';
import '../circulation_store.dart';
import '../library_models.dart';
import '../widgets/person_search_dialog.dart';

/// Utlåningen — det som står på skärmen i biblioteket. Blippa ett lånekort
/// och sedan böckerna; en utlånad bok som blippas lämnas tillbaka.
class CirculationPage extends CompositionWidget {
  const CirculationPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final store = inject(circulationStoreKey);
    final hub = inject(readerHubKey);
    final kiosk = inject(kioskStoreKey);
    final auth = inject(authStoreKey);
    final contextRef = useContext();

    // Den stora rutan visar senaste händelsen en stund och går sedan tillbaka
    // till "Blippa …" — tick ritar om sidan även när inget annat ändras.
    final tick = ref(0);
    StreamSubscription<String>? sub;
    Timer? ticker;
    onMounted(() {
      sub = hub.codes.listen(store.handleCode);
      ticker = Timer.periodic(const Duration(seconds: 5), (_) => tick.value++);
    });
    onUnmounted(() {
      sub?.cancel();
      ticker?.cancel();
    });

    Future<void> chooseBorrower() async {
      final ctx = contextRef.value;
      if (ctx == null) return;
      final person = await showPersonSearch(ctx);
      if (person != null) await store.selectBorrower(person);
    }

    Future<void> typeCode() async {
      final ctx = contextRef.value;
      if (ctx == null) return;
      final code = await showManualCode(ctx);
      if (code != null && code.trim().isNotEmpty) await store.handleCode(code.trim());
    }

    return (context) {
      tick.value;
      // I kioskläget väljer ingen låntagare i listan — då kunde en elev låna
      // i någon annans namn. Utan kort lånar man i webben eller hos personalen.
      final manual = !kiosk.active.value;
      final latest = store.events.value.isEmpty ? null : store.events.value.first;
      return Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              title: 'Utlåning',
              subtitle: 'Blippa ditt lånekort och sedan böckerna. En utlånad bok som blippas lämnas tillbaka.',
              actions: [
                if (manual)
                  OutlinedButton.icon(
                    onPressed: typeCode,
                    icon: const Icon(Icons.keyboard_outlined),
                    label: const Text('Skriv kod'),
                  ),
              ],
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ScanHero(busy: store.busy.value, latest: latest),
                        const SizedBox(height: 20),
                        Expanded(child: _EventLog(events: store.events.value.skip(1).toList())),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  SizedBox(
                    width: 380,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (store.pending.value != null) ...[
                            _PendingCard(
                              pending: store.pending.value!,
                              onCancel: store.cancelPending,
                              onChoose: manual ? chooseBorrower : null,
                            ),
                            const SizedBox(height: 20),
                          ],
                          _BorrowerCard(
                            borrower: store.borrower.value,
                            loans: store.borrowerLoans.value,
                            secondsLeft: store.secondsLeft.value,
                            onChoose: manual ? chooseBorrower : null,
                            onDone: store.endSession,
                            maxRenewals: auth.maxRenewals.value,
                            onRenew: store.renew,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    };
  }
}

class _ScanHero extends StatelessWidget {
  const _ScanHero({required this.busy, required this.latest});

  final bool busy;
  final CirculationEvent? latest;

  @override
  Widget build(BuildContext context) {
    final event = latest;
    // Senaste händelsen syns stort en stund; annars uppmaningen att blippa.
    final fresh = event != null && DateTime.now().difference(event.time).inSeconds < 20;
    final (bg, fg, icon) = switch (fresh ? event.kind : null) {
      EventKind.lent => (AppColors.successLight, AppColors.success, Icons.check_circle_outline),
      EventKind.returned => (AppColors.successLight, AppColors.success, Icons.keyboard_return),
      EventKind.card => (AppColors.primaryLight, AppColors.onPrimaryLight, Icons.badge_outlined),
      EventKind.info => (AppColors.sunLight, AppColors.onSunLight, Icons.menu_book_outlined),
      EventKind.error => (AppColors.errorLight, AppColors.error, Icons.error_outline),
      null => (AppColors.surface, AppColors.primary, Icons.contactless_outlined),
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: fresh ? fg.withValues(alpha: 0.25) : AppColors.line),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            height: 88,
            child: busy
                ? const Padding(padding: EdgeInsets.all(18), child: CircularProgressIndicator(strokeWidth: 4))
                : Icon(icon, size: 80, color: fg),
          ),
          const SizedBox(width: 28),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fresh ? event.title : 'Blippa en bok eller ditt lånekort',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: fresh ? fg : AppColors.ink, height: 1.15),
                ),
                const SizedBox(height: 8),
                Text(
                  fresh ? event.detail : 'Lägg boken eller kortet på läsaren.',
                  style: const TextStyle(fontSize: 18, color: AppColors.ink2, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EventLog extends StatelessWidget {
  const _EventLog({required this.events});
  final List<CirculationEvent> events;

  static final _time = DateFormat('HH:mm');

  @override
  Widget build(BuildContext context) {
    return Card(
      child: events.isEmpty
          ? const EmptyState(icon: Icons.history, title: 'Inget har hänt än', text: 'Lån och återlämningar visas här.')
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: events.length,
              separatorBuilder: (_, _) => const Divider(indent: 20, endIndent: 20),
              itemBuilder: (context, i) {
                final e = events[i];
                final (icon, color) = switch (e.kind) {
                  EventKind.lent => (Icons.north_east, AppColors.success),
                  EventKind.returned => (Icons.keyboard_return, AppColors.success),
                  EventKind.card => (Icons.badge_outlined, AppColors.primary),
                  EventKind.info => (Icons.menu_book_outlined, AppColors.warning),
                  EventKind.error => (Icons.error_outline, AppColors.error),
                };
                return ListTile(
                  leading: Icon(icon, color: color),
                  title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: e.detail.isEmpty ? null : Text(e.detail),
                  trailing: Text(_time.format(e.time), style: const TextStyle(color: AppColors.ink3)),
                );
              },
            ),
    );
  }
}

class _PendingCard extends StatelessWidget {
  const _PendingCard({required this.pending, required this.onCancel, required this.onChoose});

  final PendingCopy pending;
  final VoidCallback onCancel;
  final VoidCallback? onChoose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.sunLight, borderRadius: BorderRadius.circular(AppRadius.card)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('VÄNTAR PÅ LÅNTAGARE', style: sectionLabelStyle(context).copyWith(color: AppColors.onSunLight)),
          const SizedBox(height: 6),
          Text(pending.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          if (pending.location.isNotEmpty) Text(pending.location, style: const TextStyle(color: AppColors.ink2)),
          const SizedBox(height: 14),
          Row(
            children: [
              if (onChoose != null) ...[
                FilledButton(onPressed: onChoose, child: const Text('Välj låntagare')),
                const SizedBox(width: 8),
              ],
              TextButton(onPressed: onCancel, child: const Text('Avbryt')),
            ],
          ),
        ],
      ),
    );
  }
}

class _BorrowerCard extends StatelessWidget {
  const _BorrowerCard({
    required this.borrower,
    required this.loans,
    required this.secondsLeft,
    required this.onChoose,
    required this.onDone,
    required this.maxRenewals,
    required this.onRenew,
  });

  final LibraryPerson? borrower;
  final List<LibraryLoan> loans;
  final int? secondsLeft;
  final VoidCallback? onChoose;
  final VoidCallback onDone;
  final int maxRenewals;
  final void Function(LibraryLoan) onRenew;

  @override
  Widget build(BuildContext context) {
    final person = borrower;
    if (person == null) {
      return SectionCard(
        title: 'Låntagare',
        icon: Icons.person_outline,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              onChoose != null
                  ? 'Blippa lånekortet. Har eleven inget kort kan du välja eleven i listan.'
                  : 'Blippa ditt lånekort. Har du inget kort? Låna i Skolpunkten på webben eller fråga personalen.',
              style: const TextStyle(color: AppColors.ink2, height: 1.4),
            ),
            if (onChoose != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onChoose,
                icon: const Icon(Icons.person_search_outlined),
                label: const Text('Välj låntagare'),
              ),
            ],
          ],
        ),
      );
    }
    return SectionCard(
      title: person.name,
      icon: Icons.person,
      trailing: secondsLeft == null
          ? null
          : Text('${secondsLeft}s', style: const TextStyle(color: AppColors.ink3, fontFeatures: [FontFeature.tabularFigures()])),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (person.description.isNotEmpty)
            Text(person.description, style: const TextStyle(color: AppColors.ink2)),
          const SizedBox(height: 14),
          Text('LÅNADE BÖCKER', style: sectionLabelStyle(context)),
          const SizedBox(height: 6),
          if (loans.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Inga lån just nu.', style: TextStyle(color: AppColors.ink3)),
            )
          else
            for (final loan in loans)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(loan.title?.title ?? 'Bok', style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(
                            loan.isOverdue ? 'Försenad sedan ${formatDue(loan.dueAt)}' : 'Åter senast ${formatDue(loan.dueAt)}',
                            style: TextStyle(color: loan.isOverdue ? AppColors.error : AppColors.ink3, fontSize: 13.5),
                          ),
                        ],
                      ),
                    ),
                    if (loan.isOverdue) StatusPill.error('Försenad'),
                    if (loan.renewals < maxRenewals)
                      TextButton(onPressed: () => onRenew(loan), child: const Text('Förläng')),
                  ],
                ),
              ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onDone,
            icon: const Icon(Icons.check),
            label: const Text('Klar'),
          ),
        ],
      ),
    );
  }
}
