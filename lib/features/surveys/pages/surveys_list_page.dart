import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/injection_keys.dart';

class SurveysListPage extends CompositionWidget {
  const SurveysListPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final surveysStore = inject(surveysStoreKey);

    // Load surveys on init
    onMounted(() {
      surveysStore.fetchAll();
    });

    return (context) {
      final surveys = surveysStore.surveys.value;
      final loading = surveysStore.loading.value;

      return Scaffold(
        appBar: AppBar(
          title: const Text('Undersökningar'),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : surveys.isEmpty
                ? const Center(
                    child: Text('Inga undersökningar ännu'),
                  )
                : ListView.builder(
                    itemCount: surveys.length,
                    itemBuilder: (context, index) {
                      final survey = surveys[index];
                      return ListTile(
                        title: Text(survey.title),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () {
                                context.push('/edit-survey/${survey.id}');
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Bekräfta borttagning'),
                                    content: const Text(
                                      'Är du säker på att du vill ta bort denna undersökning?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(false),
                                        child: const Text('Avbryt'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(true),
                                        child: const Text('Ta bort'),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm == true) {
                                  await surveysStore.delete(survey.id);
                                  surveysStore.fetchAll();
                                }
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            context.push('/create-survey');
          },
          child: const Icon(Icons.add),
        ),
      );
    };
  }
}
