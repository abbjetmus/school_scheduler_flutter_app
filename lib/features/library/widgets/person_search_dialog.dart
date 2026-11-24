import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';

import '../../../core/di/injection_keys.dart';
import '../../../core/theme/app_theme.dart';
import '../library_models.dart';

/// Sök en person i skolan. Returnerar den valda personen.
Future<LibraryPerson?> showPersonSearch(BuildContext context, {String title = 'Välj låntagare'}) {
  return showDialog<LibraryPerson>(context: context, builder: (_) => _PersonSearchDialog(title: title));
}

class _PersonSearchDialog extends CompositionWidget {
  const _PersonSearchDialog({required this.title});
  final String title;

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final api = inject(libraryApiKey);
    final (controller, text, _) = useTextEditingController();
    final results = ref<List<LibraryPerson>>([]);
    final loading = ref(false);
    final error = ref<String?>(null);
    Timer? debounce;

    void search(String query) {
      debounce?.cancel();
      if (query.trim().length < 2) {
        results.value = [];
        return;
      }
      debounce = Timer(const Duration(milliseconds: 250), () async {
        loading.value = true;
        try {
          results.value = await api.searchPeople(query);
          error.value = null;
        } catch (e) {
          error.value = e.toString();
        } finally {
          loading.value = false;
        }
      });
    }

    onUnmounted(() => debounce?.cancel());

    return (context) => AlertDialog(
          title: Text(props.value.title),
          content: SizedBox(
            width: 480,
            height: 420,
            child: Column(
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Sök på namn eller e-post',
                    prefixIcon: const Icon(Icons.person_search_outlined),
                    suffixIcon: loading.value
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : null,
                  ),
                  onChanged: search,
                ),
                const SizedBox(height: 12),
                if (error.value != null) Text(error.value!, style: const TextStyle(color: AppColors.error)),
                Expanded(
                  child: results.value.isEmpty
                      ? Center(
                          child: Text(
                            text.value.trim().length < 2 ? 'Skriv minst två bokstäver.' : 'Ingen träff.',
                            style: const TextStyle(color: AppColors.ink3),
                          ),
                        )
                      : ListView.separated(
                          itemCount: results.value.length,
                          separatorBuilder: (_, _) => const Divider(),
                          itemBuilder: (context, i) {
                            final person = results.value[i];
                            return ListTile(
                              leading: const Icon(Icons.person_outline),
                              title: Text(person.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text([person.description, person.email].where((s) => s.isNotEmpty).join(' · ')),
                              onTap: () => Navigator.of(context).pop(person),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Avbryt'))],
        );
  }
}

/// Skriv in en kod för hand (när läsaren inte fungerar, eller ett ISBN).
Future<String?> showManualCode(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Skriv in en kod'),
      content: SizedBox(
        width: 420,
        child: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'RFID, streckkod, kortnummer eller ISBN',
            prefixIcon: Icon(Icons.keyboard_outlined),
          ),
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Avbryt')),
        FilledButton(onPressed: () => Navigator.of(context).pop(controller.text), child: const Text('Skicka')),
      ],
    ),
  ).whenComplete(controller.dispose);
}
