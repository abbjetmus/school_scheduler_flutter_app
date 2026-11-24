import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/di/injection_keys.dart';
import '../../../core/pocketbase/pocketbase_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui.dart';
import '../circulation_store.dart';
import '../library_api.dart';
import '../library_models.dart';

/// Vad nästa blippade etikett ska användas till.
sealed class _TagTarget {
  const _TagTarget();
}

class _TagCopy extends _TagTarget {
  const _TagCopy(this.copy);
  final LibraryCopy copy;
}

class _NewCopy extends _TagTarget {
  const _NewCopy();
}

/// Böckerna — sök, se exemplaren och koppla RFID-etiketter genom att blippa.
/// Nya böcker läggs in i Skolpunkten på webben (ISBN-uppslag, import).
///
/// Blippar man en etikett när inget exemplar väntar på en visas boken den
/// sitter på — bra för att ta reda på vad en bok är.
class BooksPage extends CompositionWidget {
  const BooksPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final api = inject(libraryApiKey);
    final hub = inject(readerHubKey);
    final contextRef = useContext();
    final (searchController, search, _) = useTextEditingController();

    final titles = ref<List<LibraryTitle>>([]);
    final loading = ref(true);
    final selected = ref<LibraryTitle?>(null);
    final copies = ref<List<LibraryCopy>>([]);
    final copiesLoading = ref(false);
    final target = ref<_TagTarget?>(null);
    final untaggedOnly = ref(false);
    final allCopies = ref<List<LibraryCopy>>([]);

    void toast(String message, {bool error = false}) {
      final ctx = contextRef.value;
      if (ctx != null && ctx.mounted) showMessage(ctx, message, error: error);
    }

    Future<void> loadTitles() async {
      loading.value = true;
      try {
        final result = await Future.wait([api.titles(), api.copies()]);
        titles.value = result[0] as List<LibraryTitle>;
        allCopies.value = result[1] as List<LibraryCopy>;
      } on LibraryException catch (e) {
        toast(e.message, error: true);
      } finally {
        loading.value = false;
      }
    }

    Future<void> select(LibraryTitle title) async {
      selected.value = title;
      target.value = null;
      copiesLoading.value = true;
      try {
        copies.value = await api.copies(title: title.id);
      } on LibraryException catch (e) {
        toast(e.message, error: true);
      } finally {
        copiesLoading.value = false;
      }
    }

    Future<void> onCode(String code) async {
      final t = target.value;
      final title = selected.value;
      try {
        if (t is _TagCopy) {
          await api.setCopyRfid(t.copy.id, code);
          hub.playSuccess();
          toast('Etiketten är kopplad till exemplaret${t.copy.location.isNotEmpty ? ' på ${t.copy.location}' : ''}.');
          target.value = null;
        } else if (t is _NewCopy && title != null) {
          final location = copies.value.where((c) => c.location.isNotEmpty).firstOrNull?.location ?? '';
          await api.addCopy(title.id, location: location, rfid: code);
          hub.playSuccess();
          toast('Nytt exemplar av ${title.title} med etikett.');
          target.value = null;
        } else {
          final result = await api.scan(code);
          switch (result) {
            case ScannedCopy(:final title):
            case ScannedIsbn(:final title):
              final match = titles.value.where((x) => x.id == title.id).firstOrNull ?? title;
              hub.playCard();
              await select(match);
              return;
            case ScannedCard(:final person):
              hub.playError();
              toast('Det där är ${person.name}s passerkort, inte en bok.', error: true);
              return;
            case ScannedUnknown():
              hub.playError();
              toast('Etiketten ${result.code} sitter inte på någon bok. Välj ett exemplar och tryck "Koppla etikett".',
                  error: true);
              return;
          }
        }
        if (title != null) await select(title);
        unawaited(loadTitles());
      } on LibraryException catch (e) {
        hub.playError();
        toast(e.message, error: true);
      }
    }

    StreamSubscription<String>? sub;
    onMounted(() {
      loadTitles();
      sub = hub.codes.listen(onCode);
    });
    onUnmounted(() => sub?.cancel());

    final untaggedByTitle = computed(() {
      final map = <String, int>{};
      for (final c in allCopies.value) {
        if (c.rfid.isEmpty && c.status != 'withdrawn') map[c.titleId] = (map[c.titleId] ?? 0) + 1;
      }
      return map;
    });

    final filtered = computed(() {
      final q = search.value.trim().toLowerCase();
      return titles.value.where((t) {
        if (untaggedOnly.value && (untaggedByTitle.value[t.id] ?? 0) == 0) return false;
        if (q.isEmpty) return true;
        if (q.startsWith('#')) return t.tags.any((tag) => tag.startsWith(q.substring(1)));
        return '${t.title} ${t.author} ${t.isbn}'.toLowerCase().contains(q);
      }).toList();
    });

    Future<void> removeTag(LibraryCopy copy) async {
      try {
        await api.setCopyRfid(copy.id, '');
        toast('Etiketten är borttagen.');
        if (selected.value != null) await select(selected.value!);
        unawaited(loadTitles());
      } on LibraryException catch (e) {
        toast(e.message, error: true);
      }
    }

    return (context) => Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: 'Böcker',
                subtitle: 'Koppla RFID-etiketter till exemplaren. Nya böcker läggs in i Skolpunkten på webben.',
                actions: [
                  OutlinedButton.icon(
                    onPressed: () => launchUrl(Uri.parse('${PocketBaseClient.webUrl}/library/books')),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Lägg till böcker'),
                  ),
                ],
              ),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 420,
                      child: Card(
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                              child: TextField(
                                controller: searchController,
                                decoration: const InputDecoration(
                                  hintText: 'Sök titel, författare, ISBN eller #tagg',
                                  prefixIcon: Icon(Icons.search),
                                  isDense: true,
                                ),
                              ),
                            ),
                            CheckboxListTile(
                              dense: true,
                              value: untaggedOnly.value,
                              onChanged: (v) => untaggedOnly.value = v ?? false,
                              title: const Text('Bara böcker med exemplar utan etikett'),
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                            const Divider(),
                            Expanded(
                              child: loading.value
                                  ? const Center(child: CircularProgressIndicator())
                                  : filtered.value.isEmpty
                                      ? const EmptyState(icon: Icons.menu_book_outlined, title: 'Inga böcker')
                                      : ListView.builder(
                                          itemCount: filtered.value.length,
                                          itemBuilder: (context, i) {
                                            final t = filtered.value[i];
                                            final missing = untaggedByTitle.value[t.id] ?? 0;
                                            return ListTile(
                                              selected: selected.value?.id == t.id,
                                              selectedTileColor: AppColors.primaryLight,
                                              title: Text(t.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                                              subtitle: Text(t.author),
                                              trailing: missing > 0
                                                  ? Tooltip(
                                                      message: '$missing exemplar utan etikett',
                                                      child: StatusPill.warning('$missing'),
                                                    )
                                                  : null,
                                              onTap: () => select(t),
                                            );
                                          },
                                        ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: selected.value == null
                          ? const Card(
                              child: EmptyState(
                                icon: Icons.contactless_outlined,
                                title: 'Välj en bok — eller blippa en',
                                text: 'Blippar du en bok visas vilken det är och var den ska stå.',
                              ),
                            )
                          : _CopiesPanel(
                              title: selected.value!,
                              copies: copies.value,
                              loading: copiesLoading.value,
                              target: target.value,
                              onTag: (c) => target.value = _TagCopy(c),
                              onNew: () => target.value = const _NewCopy(),
                              onCancel: () => target.value = null,
                              onRemoveTag: removeTag,
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

class _CopiesPanel extends StatelessWidget {
  const _CopiesPanel({
    required this.title,
    required this.copies,
    required this.loading,
    required this.target,
    required this.onTag,
    required this.onNew,
    required this.onCancel,
    required this.onRemoveTag,
  });

  final LibraryTitle title;
  final List<LibraryCopy> copies;
  final bool loading;
  final _TagTarget? target;
  final void Function(LibraryCopy) onTag;
  final VoidCallback onNew;
  final VoidCallback onCancel;
  final void Function(LibraryCopy) onRemoveTag;

  Widget _state(LibraryCopy c) => switch (c.state) {
        CopyStatus.available => StatusPill.success('Finns'),
        CopyStatus.loaned => c.dueAt != null && c.dueAt!.isBefore(DateTime.now())
            ? StatusPill.error('Försenad · ${c.borrowerName}')
            : StatusPill.primary('Utlånad · ${c.borrowerName}'),
        CopyStatus.missing => StatusPill.warning('Saknas'),
        CopyStatus.withdrawn => const StatusPill('Gallrad'),
      };

  @override
  Widget build(BuildContext context) {
    final t = target;
    return Card(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(title.title, style: pageTitleStyle(context).copyWith(fontSize: 24)),
          if (title.author.isNotEmpty) Text('av ${title.author}', style: const TextStyle(color: AppColors.ink2, fontSize: 15)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            children: [
              if (title.isbn.isNotEmpty) Text('ISBN ${title.isbn}', style: const TextStyle(color: AppColors.ink3)),
              if (title.edition.isNotEmpty) Text('Upplaga ${title.edition}', style: const TextStyle(color: AppColors.ink3)),
              for (final tag in title.tags) Text('#$tag', style: const TextStyle(color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 20),
          if (t != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: AppColors.sunLight, borderRadius: BorderRadius.circular(AppRadius.tile)),
              child: Row(
                children: [
                  const Icon(Icons.contactless, color: AppColors.onSunLight, size: 36),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      t is _TagCopy
                          ? 'Blippa etiketten som sitter på exemplaret${t.copy.location.isNotEmpty ? ' på ${t.copy.location}' : ''}.'
                          : 'Blippa etiketten på det nya exemplaret.',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.onSunLight),
                    ),
                  ),
                  TextButton(onPressed: onCancel, child: const Text('Avbryt')),
                ],
              ),
            ),
          Row(
            children: [
              Text('EXEMPLAR', style: sectionLabelStyle(context)),
              const Spacer(),
              TextButton.icon(onPressed: onNew, icon: const Icon(Icons.add), label: const Text('Nytt exemplar med etikett')),
            ],
          ),
          if (loading)
            const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
          else if (copies.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('Inga exemplar ännu.', style: TextStyle(color: AppColors.ink3)),
            )
          else
            for (final c in copies) ...[
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.location.isEmpty ? 'Ingen placering' : c.location,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          _state(c),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Row(
                        children: [
                          Icon(Icons.contactless_outlined,
                              size: 18, color: c.rfid.isEmpty ? AppColors.lineStrong : AppColors.ink2),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              c.rfid.isEmpty ? 'Ingen etikett' : c.rfid,
                              style: TextStyle(color: c.rfid.isEmpty ? AppColors.ink3 : AppColors.ink, fontFamily: c.rfid.isEmpty ? null : 'monospace'),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (c.rfid.isNotEmpty)
                      IconButton(
                        tooltip: 'Ta bort etiketten',
                        onPressed: () => onRemoveTag(c),
                        icon: const Icon(Icons.link_off, size: 20),
                      ),
                    const SizedBox(width: 4),
                    OutlinedButton(
                      onPressed: () => onTag(c),
                      child: Text(c.rfid.isEmpty ? 'Koppla etikett' : 'Byt etikett'),
                    ),
                  ],
                ),
              ),
              if (c.state == CopyStatus.loaned && c.dueAt != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('Åter senast ${formatDue(c.dueAt)}', style: const TextStyle(color: AppColors.ink3, fontSize: 13)),
                ),
            ],
        ],
      ),
    );
  }
}
