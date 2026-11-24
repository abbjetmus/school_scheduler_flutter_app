import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';

import '../../../core/di/injection_keys.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui.dart';
import '../library_api.dart';
import '../library_models.dart';
import '../widgets/person_search_dialog.dart';

/// Lånekort: välj en person och blippa kortet. Ett kort per person — ett nytt
/// kort ersätter det gamla. Blippas ett kort utan att någon är vald visas vems
/// det är.
class CardsPage extends CompositionWidget {
  const CardsPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final api = inject(libraryApiKey);
    final hub = inject(readerHubKey);
    final contextRef = useContext();
    final (searchController, search, _) = useTextEditingController();

    final cards = ref<List<(LibraryPerson, String)>>([]);
    final loading = ref(true);
    final person = ref<LibraryPerson?>(null);
    final status = ref<String?>(null);

    void toast(String message, {bool error = false}) {
      final ctx = contextRef.value;
      if (ctx != null && ctx.mounted) showMessage(ctx, message, error: error);
    }

    Future<void> load() async {
      try {
        cards.value = await api.cards();
      } on LibraryException catch (e) {
        toast(e.message, error: true);
      } finally {
        loading.value = false;
      }
    }

    Future<void> onCode(String code) async {
      final p = person.value;
      try {
        if (p != null) {
          await api.setCard(p.id, code);
          hub.playSuccess();
          status.value = 'Kortet är kopplat till ${p.name}.';
          person.value = null;
          await load();
          return;
        }
        final result = await api.scan(code);
        if (result is ScannedCard) {
          hub.playCard();
          status.value = 'Kortet tillhör ${result.person.name}${result.person.className.isNotEmpty ? ' (${result.person.className})' : ''}.';
        } else if (result is ScannedCopy) {
          hub.playError();
          status.value = 'Det där är en bok: ${result.title.title}.';
        } else {
          hub.playError();
          status.value = 'Kortet ${normalizeLibraryCode(code)} är inte kopplat till någon. Välj en person först.';
        }
      } on LibraryException catch (e) {
        hub.playError();
        status.value = e.message;
      }
    }

    Future<void> choose() async {
      final ctx = contextRef.value;
      if (ctx == null) return;
      final picked = await showPersonSearch(ctx, title: 'Vem är kortet till?');
      if (picked != null) {
        person.value = picked;
        status.value = null;
      }
    }

    Future<void> remove(LibraryPerson p) async {
      try {
        await api.setCard(p.id, '');
        toast('Kortet är borttaget från ${p.name}.');
        await load();
      } on LibraryException catch (e) {
        toast(e.message, error: true);
      }
    }

    StreamSubscription<String>? sub;
    onMounted(() {
      load();
      sub = hub.codes.listen(onCode);
    });
    onUnmounted(() => sub?.cancel());

    final filtered = computed(() {
      final q = search.value.trim().toLowerCase();
      if (q.isEmpty) return cards.value;
      return cards.value
          .where((c) => '${c.$1.name} ${c.$1.email} ${c.$1.className} ${c.$2}'.toLowerCase().contains(q))
          .toList();
    });

    return (context) => Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const PageHeader(
                title: 'Lånekort',
                subtitle: 'Elev- eller passerkort som man blippar för att låna. Ett kort per person.',
              ),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 400,
                      child: SectionCard(
                        title: 'Koppla ett kort',
                        icon: Icons.badge_outlined,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (person.value == null) ...[
                              const Text('1. Välj personen.  2. Blippa kortet.', style: TextStyle(color: AppColors.ink2)),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                onPressed: choose,
                                icon: const Icon(Icons.person_search_outlined),
                                label: const Text('Välj person'),
                              ),
                            ] else ...[
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: AppColors.sunLight,
                                  borderRadius: BorderRadius.circular(AppRadius.tile),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.contactless, size: 36, color: AppColors.onSunLight),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(person.value!.name,
                                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                                          const Text('Blippa kortet nu.', style: TextStyle(color: AppColors.onSunLight)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextButton(onPressed: () => person.value = null, child: const Text('Avbryt')),
                            ],
                            if (status.value != null) ...[
                              const SizedBox(height: 16),
                              Text(status.value!, style: const TextStyle(fontWeight: FontWeight.w600)),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Card(
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: TextField(
                                controller: searchController,
                                decoration: const InputDecoration(
                                  hintText: 'Sök person eller kort',
                                  prefixIcon: Icon(Icons.search),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const Divider(),
                            Expanded(
                              child: loading.value
                                  ? const Center(child: CircularProgressIndicator())
                                  : filtered.value.isEmpty
                                      ? const EmptyState(icon: Icons.badge_outlined, title: 'Inga kort kopplade')
                                      : ListView.separated(
                                          itemCount: filtered.value.length,
                                          separatorBuilder: (_, _) => const Divider(indent: 16, endIndent: 16),
                                          itemBuilder: (context, i) {
                                            final (p, cardId) = filtered.value[i];
                                            return ListTile(
                                              leading: const Icon(Icons.person_outline),
                                              title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                              subtitle: Text([p.description, p.email].where((s) => s.isNotEmpty).join(' · ')),
                                              trailing: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(cardId, style: const TextStyle(fontFamily: 'monospace', color: AppColors.ink3)),
                                                  IconButton(
                                                    tooltip: 'Ta bort kortet',
                                                    icon: const Icon(Icons.link_off, color: AppColors.error),
                                                    onPressed: () => remove(p),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
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
  }
}
