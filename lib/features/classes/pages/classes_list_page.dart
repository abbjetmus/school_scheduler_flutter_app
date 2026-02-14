import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/models/pocketbase_types.dart';
import '../classes_store.dart';
import '../../auth/auth_store.dart' as app_auth;

class ClassesListPage extends CompositionWidget {
  const ClassesListPage({super.key});

  static const String path = '/classes';

  @override
  Widget Function(BuildContext) setup() {
    final classesStore = inject(classesStoreKey);
    final authStore = inject(authStoreKey);
    final searchQuery = ref('');

    final filteredClasses = computed(() {
      final query = searchQuery.value.toLowerCase();
      if (query.isEmpty) return classesStore.classes.value;
      return classesStore.classes.value
          .where((c) =>
              (c.name ?? '').toLowerCase().contains(query) ||
              c.extraInfo.any((info) => info.toLowerCase().contains(query)))
          .toList();
    });

    onMounted(() {
      classesStore.getClasses();
    });

    return (context) {
      final classes = filteredClasses.value;
      final loading = classesStore.loading.value;

      return Scaffold(
        appBar: AppBar(
          title: const Text('Klasser'),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Sök klasser',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  searchQuery.value = value;
                },
              ),
            ),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : classes.isEmpty
                      ? Center(
                          child: Text(
                            searchQuery.value.isNotEmpty
                                ? 'Inga klasser matchar sökningen'
                                : 'Inga klasser ännu',
                          ),
                        )
                      : ListView.builder(
                          itemCount: classes.length,
                          itemBuilder: (context, index) {
                            final classGroup = classes[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: ListTile(
                                title: Text(classGroup.name ?? ''),
                                subtitle: classGroup.extraInfo.isNotEmpty
                                    ? Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        children: classGroup.extraInfo
                                            .map((info) => Chip(
                                                  label: Text(info),
                                                  materialTapTargetSize:
                                                      MaterialTapTargetSize
                                                          .shrinkWrap,
                                                ))
                                            .toList(),
                                      )
                                    : null,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: () {
                                        _showClassDialog(
                                          context,
                                          classesStore,
                                          authStore,
                                          classGroup: classGroup,
                                        );
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete),
                                      onPressed: () {
                                        _showDeleteDialog(
                                          context,
                                          classesStore,
                                          classGroup,
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            _showClassDialog(context, classesStore, authStore);
          },
          child: const Icon(Icons.add),
        ),
      );
    };
  }

  void _showClassDialog(
    BuildContext context,
    ClassesStore classesStore,
    app_auth.AuthStore authStore, {
    ClassGroup? classGroup,
  }) {
    final nameController = TextEditingController(text: classGroup?.name ?? '');
    final extraInfoController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (statefulContext, setState) {
            List<String> extraInfoList = List<String>.from(classGroup?.extraInfo ?? []);

            return AlertDialog(
              title: Text(classGroup == null ? 'Lägg till klass' : 'Redigera klass'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Namn',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Extra information',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: extraInfoController,
                            decoration: const InputDecoration(
                              labelText: 'Lägg till info',
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: (value) {
                              if (value.trim().isNotEmpty) {
                                setState(() {
                                  extraInfoList.add(value.trim());
                                });
                                extraInfoController.clear();
                              }
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () {
                            final value = extraInfoController.text.trim();
                            if (value.isNotEmpty) {
                              setState(() {
                                extraInfoList.add(value);
                              });
                              extraInfoController.clear();
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: extraInfoList.map((info) {
                        return Chip(
                          label: Text(info),
                          onDeleted: () {
                            setState(() {
                              extraInfoList.remove(info);
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Avbryt'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Namn krävs'),
                        ),
                      );
                      return;
                    }

                    final data = {
                      'name': name,
                      'school': authStore.currentSchoolId,
                      'extraInfo': extraInfoList,
                    };

                    bool success;
                    if (classGroup == null) {
                      success = await classesStore.createClass(data);
                    } else {
                      success = await classesStore.updateClass(
                        classGroup.id,
                        data,
                      );
                    }

                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            success
                                ? (classGroup == null
                                    ? 'Klass skapad'
                                    : 'Klass uppdaterad')
                                : 'Ett fel uppstod',
                          ),
                        ),
                      );
                    }
                  },
                  child: Text(classGroup == null ? 'Lägg till' : 'Uppdatera'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    ClassesStore classesStore,
    ClassGroup classGroup,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Ta bort klass'),
          content: Text(
            'Är du säker på att du vill ta bort "${classGroup.name ?? ''}"?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Avbryt'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final success = await classesStore.removeClass(classGroup.id);

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success ? 'Klass borttagen' : 'Ett fel uppstod',
                      ),
                    ),
                  );
                }
              },
              child: const Text('Ta bort'),
            ),
          ],
        );
      },
    );
  }
}
