import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';

import '../../../core/di/injection_keys.dart';
import '../../../core/theme/app_theme.dart';
import '../library_api.dart';
import '../library_models.dart';

/// Boken som lades in (eller fick nya exemplar) och exemplaren som skapades.
typedef AddedBook = ({LibraryTitle title, List<LibraryCopy> copies});

/// Lägg in en bok genom att skanna streckkoden (ISBN) på baksidan — samma som
/// "Lägg till bok" på webben (LibraryTitleDialog.vue). Uppgifterna hämtas från
/// Libris, Open Library eller Google Books. Finns boken redan läggs bara nya
/// exemplar till.
///
/// [isbn] är ett ISBN som redan skannats — då hämtas uppgifterna direkt.
/// [titles] är katalogen, för att känna igen en bok som redan finns.
Future<AddedBook?> showAddBookDialog(
  BuildContext context, {
  String isbn = '',
  required List<LibraryTitle> titles,
}) {
  return showDialog<AddedBook>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _AddBookDialog(isbn: isbn, titles: titles),
  );
}

class _AddBookDialog extends CompositionWidget {
  const _AddBookDialog({required this.isbn, required this.titles});
  final String isbn;
  final List<LibraryTitle> titles;

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final api = inject(libraryApiKey);
    final hub = inject(readerHubKey);

    final (isbnController, isbnText, _) = useTextEditingController(text: props.value.isbn);
    final (titleController, titleText, _) = useTextEditingController();
    final (authorController, _, _) = useTextEditingController();
    final (editionController, _, _) = useTextEditingController();
    final (publisherController, _, _) = useTextEditingController();
    final (tagsController, _, _) = useTextEditingController();
    final (locationController, _, _) = useTextEditingController();

    final copies = ref(1);
    final coverUrl = ref('');
    final source = ref<String?>(null);
    final isbnError = ref<String?>(null);
    final notFound = ref(false);
    final duplicate = ref<LibraryTitle?>(null);
    final lookingUp = ref(false);
    final saving = ref(false);
    final saveError = ref<String?>(null);

    LibraryTitle? findDuplicate(String isbn) =>
        isbn.isEmpty ? null : props.value.titles.where((t) => t.isbn == isbn).firstOrNull;

    Future<void> lookup() async {
      isbnError.value = null;
      notFound.value = false;
      source.value = null;
      final isbn = normalizeLibraryIsbn(isbnController.text);
      if (isbn.isEmpty) {
        isbnError.value = 'ISBN ska ha 10 eller 13 siffror.';
        return;
      }
      isbnController.text = isbn;
      duplicate.value = findDuplicate(isbn);
      if (duplicate.value != null) {
        hub.playCard();
        return;
      }
      lookingUp.value = true;
      try {
        final book = await api.lookupIsbn(isbn);
        if (book == null) {
          notFound.value = true;
          hub.playError();
          return;
        }
        titleController.text = book.title;
        authorController.text = book.author;
        editionController.text = book.edition;
        publisherController.text = book.publisher;
        coverUrl.value = book.coverUrl;
        source.value = book.source;
        hub.playSuccess();
      } on LibraryException catch (e) {
        isbnError.value = e.message;
      } finally {
        lookingUp.value = false;
      }
    }

    // Streckkodsläsaren skriver i ISBN-fältet när det har fokus. Har inget
    // fält fokus kommer koden via läsaren i stället.
    StreamSubscription<String>? sub;
    onMounted(() {
      sub = hub.codes.listen((code) {
        if (saving.value || !isValidLibraryIsbn(code)) return;
        isbnController.text = code;
        lookup();
      });
      if (props.value.isbn.isNotEmpty) lookup();
    });
    onUnmounted(() => sub?.cancel());

    Future<void> save(BuildContext context) async {
      final isbnRaw = isbnController.text.trim();
      final isbn = normalizeLibraryIsbn(isbnRaw);
      if (isbnRaw.isNotEmpty && isbn.isEmpty) {
        isbnError.value = 'ISBN ska ha 10 eller 13 siffror.';
        return;
      }
      duplicate.value ??= findDuplicate(isbn);
      saving.value = true;
      saveError.value = null;
      try {
        final title = duplicate.value ??
            await api.createTitle(
              title: titleController.text.trim(),
              author: authorController.text.trim(),
              isbn: isbn,
              edition: editionController.text.trim(),
              publisher: publisherController.text.trim(),
              tags: tagsController.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList(),
              coverUrl: coverUrl.value,
            );
        final created = <LibraryCopy>[];
        for (var i = 0; i < copies.value; i++) {
          created.add(await api.addCopy(title.id, location: locationController.text.trim()));
        }
        if (context.mounted) Navigator.of(context).pop<AddedBook>((title: title, copies: created));
      } on LibraryException catch (e) {
        saveError.value = e.message;
      } finally {
        saving.value = false;
      }
    }

    return (context) {
      final dup = duplicate.value;
      final locked = dup != null || saving.value;
      final canSave = !saving.value && !lookingUp.value && (dup != null || titleText.value.trim().isNotEmpty);

      Widget field(TextEditingController c, String label, {String? hint}) => TextField(
            controller: c,
            enabled: !locked,
            decoration: InputDecoration(labelText: label, hintText: hint),
          );

      return AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.add_circle_outline, color: AppColors.primary),
            SizedBox(width: 10),
            Text('Lägg till bok'),
          ],
        ),
        content: SizedBox(
          width: 640,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('HÄMTA UPPGIFTER VIA ISBN', style: sectionLabelStyle(context)),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: isbnController,
                        autofocus: props.value.isbn.isEmpty,
                        enabled: !saving.value,
                        decoration: InputDecoration(
                          labelText: 'ISBN',
                          hintText: 'Skanna streckkoden på bokens baksida eller skriv ISBN',
                          prefixIcon: const Icon(Icons.qr_code_scanner),
                          errorText: isbnError.value,
                        ),
                        onSubmitted: (_) => lookup(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: lookingUp.value || isbnText.value.trim().isEmpty || saving.value ? null : lookup,
                        icon: lookingUp.value
                            ? const SizedBox(
                                width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.search),
                        label: const Text('Hämta'),
                      ),
                    ),
                  ],
                ),
                if (source.value != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('Uppgifter från ${source.value} — kontrollera och ändra vid behov.',
                        style: const TextStyle(color: AppColors.ink3, fontSize: 13)),
                  ),
                if (notFound.value)
                  _Notice(
                    icon: Icons.info_outline,
                    text: 'Hittade ingen bok med ISBN ${isbnController.text}. Fyll i uppgifterna själv.',
                  ),
                if (dup != null)
                  _Notice(
                    icon: Icons.library_books_outlined,
                    text: '${dup.title} finns redan i biblioteket. Sparar du läggs ${copies.value} '
                        '${copies.value == 1 ? 'nytt exemplar' : 'nya exemplar'} till.',
                  ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Row(children: [
                            Expanded(flex: 7, child: field(titleController, 'Boktitel')),
                            const SizedBox(width: 10),
                            Expanded(flex: 5, child: field(authorController, 'Författare')),
                          ]),
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(flex: 5, child: field(editionController, 'Upplaga/år', hint: 'T.ex. 2024')),
                            const SizedBox(width: 10),
                            Expanded(flex: 7, child: field(publisherController, 'Förlag')),
                          ]),
                          const SizedBox(height: 10),
                          field(tagsController, 'Taggar', hint: 'Programmering, Ekonomi, Fakta — skilj med komma'),
                        ],
                      ),
                    ),
                    if (coverUrl.value.isNotEmpty && dup == null) ...[
                      const SizedBox(width: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.tile),
                        child: Image.network(
                          coverUrl.value,
                          width: 100,
                          height: 150,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),
                Text('EXEMPLAR', style: sectionLabelStyle(context)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _Stepper(
                      value: copies.value,
                      enabled: !saving.value,
                      onChanged: (v) => copies.value = v,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: locationController,
                        enabled: !saving.value,
                        decoration: const InputDecoration(
                          labelText: 'Placering på hyllan',
                          hintText: 'T.ex. Hylla A2, rad 3',
                          prefixIcon: Icon(Icons.place_outlined),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'När boken är sparad: lägg den på läsaren, så kopplas etiketten till exemplaret.',
                  style: TextStyle(color: AppColors.ink3, fontSize: 13),
                ),
                if (saveError.value != null) ...[
                  const SizedBox(height: 12),
                  Text(saveError.value!, style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: saving.value ? null : () => Navigator.of(context).pop(),
            child: const Text('Avbryt'),
          ),
          FilledButton.icon(
            onPressed: canSave ? () => save(context) : null,
            icon: saving.value
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_outlined),
            label: Text(dup != null ? 'Lägg till exemplar' : 'Spara i biblioteket'),
          ),
        ],
      );
    };
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(AppRadius.tile)),
      child: Row(
        children: [
          Icon(icon, color: AppColors.onPrimaryLight),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(color: AppColors.onPrimaryLight))),
        ],
      ),
    );
  }
}

/// Antal exemplar, 1–50 — som v-number-input med control-variant="split".
class _Stepper extends StatelessWidget {
  const _Stepper({required this.value, required this.enabled, required this.onChanged});
  final int value;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.lineStrong),
        borderRadius: BorderRadius.circular(AppRadius.tile),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Färre',
            onPressed: enabled && value > 1 ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove),
          ),
          SizedBox(
            width: 70,
            child: Text(
              value == 1 ? '1 exemplar' : '$value exemplar',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            tooltip: 'Fler',
            onPressed: enabled && value < 50 ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
