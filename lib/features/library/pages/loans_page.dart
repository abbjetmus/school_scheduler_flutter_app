import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';

import '../../../core/di/injection_keys.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui.dart';
import '../circulation_store.dart';
import '../library_api.dart';
import '../library_models.dart';

/// Pågående och försenade lån, med återlämning för hand.
class LoansPage extends CompositionWidget {
  const LoansPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final api = inject(libraryApiKey);
    final auth = inject(authStoreKey);
    final contextRef = useContext();
    final (searchController, search, _) = useTextEditingController();

    final overdueOnly = ref(false);
    final loans = ref<List<LibraryLoan>>([]);
    final loading = ref(true);
    final error = ref<String?>(null);
    final busy = ref<String?>(null);

    Future<void> load() async {
      loading.value = true;
      try {
        loans.value = await api.loans(overdueOnly: overdueOnly.value);
        error.value = null;
      } on LibraryException catch (e) {
        error.value = e.message;
      } finally {
        loading.value = false;
      }
    }

    Future<void> returnLoan(LibraryLoan loan) async {
      busy.value = loan.id;
      try {
        await api.returnBook(loan: loan.id);
        final ctx = contextRef.value;
        if (ctx != null && ctx.mounted) showMessage(ctx, '${loan.title?.title ?? 'Boken'} är återlämnad');
        await load();
      } on LibraryException catch (e) {
        final ctx = contextRef.value;
        if (ctx != null && ctx.mounted) showMessage(ctx, e.message, error: true);
      } finally {
        busy.value = null;
      }
    }

    Future<void> renew(LibraryLoan loan) async {
      busy.value = 'renew-${loan.id}';
      try {
        final updated = await api.renew(loan.id);
        final ctx = contextRef.value;
        if (ctx != null && ctx.mounted) {
          showMessage(ctx, '${loan.title?.title ?? 'Lånet'} är förlängt till ${formatDue(updated.dueAt)}');
        }
        await load();
      } on LibraryException catch (e) {
        final ctx = contextRef.value;
        if (ctx != null && ctx.mounted) showMessage(ctx, e.message, error: true);
      } finally {
        busy.value = null;
      }
    }

    onMounted(load);

    final filtered = computed(() {
      final q = search.value.trim().toLowerCase();
      if (q.isEmpty) return loans.value;
      return loans.value
          .where((l) => '${l.title?.title} ${l.title?.author} ${l.borrower?.name} ${l.borrower?.email} ${l.borrower?.className}'
              .toLowerCase()
              .contains(q))
          .toList();
    });

    return (context) => Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: 'Lån',
                subtitle: 'Böcker som är utlånade just nu.',
                actions: [
                  IconButton(tooltip: 'Uppdatera', onPressed: load, icon: const Icon(Icons.refresh)),
                ],
              ),
              Row(
                children: [
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Pågående'), icon: Icon(Icons.swap_horiz)),
                      ButtonSegment(value: true, label: Text('Försenade'), icon: Icon(Icons.warning_amber_outlined)),
                    ],
                    selected: {overdueOnly.value},
                    onSelectionChanged: (v) {
                      overdueOnly.value = v.first;
                      load();
                    },
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 360,
                    child: TextField(
                      controller: searchController,
                      decoration: const InputDecoration(
                        hintText: 'Sök på bok eller låntagare',
                        prefixIcon: Icon(Icons.search),
                        isDense: true,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text('${filtered.value.length} lån', style: const TextStyle(color: AppColors.ink3)),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Card(
                  child: loading.value
                      ? const Center(child: CircularProgressIndicator())
                      : error.value != null
                          ? EmptyState(icon: Icons.cloud_off, title: 'Kunde inte hämta lånen', text: error.value)
                          : filtered.value.isEmpty
                              ? EmptyState(
                                  icon: Icons.swap_horiz,
                                  title: overdueOnly.value ? 'Inga försenade lån' : 'Inga böcker är utlånade',
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  itemCount: filtered.value.length,
                                  separatorBuilder: (_, _) => const Divider(indent: 20, endIndent: 20),
                                  itemBuilder: (context, i) {
                                    final loan = filtered.value[i];
                                    return ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                                      title: Text(loan.title?.title ?? 'Borttagen bok',
                                          style: const TextStyle(fontWeight: FontWeight.w600)),
                                      subtitle: Text([
                                        loan.borrower?.name ?? '',
                                        loan.borrower?.className ?? '',
                                        loan.copy?.location ?? '',
                                      ].where((s) => s.isNotEmpty).join(' · ')),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          loan.isOverdue
                                              ? StatusPill.error('Försenad ${formatDue(loan.dueAt)}')
                                              : StatusPill('Åter ${formatDue(loan.dueAt)}'),
                                          const SizedBox(width: 12),
                                          if (loan.renewals < auth.maxRenewals.value) ...[
                                            TextButton(
                                              onPressed: busy.value == null ? () => renew(loan) : null,
                                              child: const Text('Förläng'),
                                            ),
                                            const SizedBox(width: 4),
                                          ],
                                          OutlinedButton(
                                            onPressed: busy.value == null ? () => returnLoan(loan) : null,
                                            child: busy.value == loan.id
                                                ? const SizedBox(
                                                    width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                                : const Text('Återlämna'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                ),
              ),
            ],
          ),
        );
  }
}
