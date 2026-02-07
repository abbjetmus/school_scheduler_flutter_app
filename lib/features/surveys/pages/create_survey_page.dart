import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:uuid/uuid.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/models/pocketbase_types.dart';

class CreateSurveyPage extends CompositionWidget {
  final String? surveyId;

  const CreateSurveyPage({super.key, this.surveyId});

  @override
  Widget Function(BuildContext) setup() {
    final surveysStore = inject(surveysStoreKey);
    final authStore = inject(authStoreKey);
    final uuid = const Uuid();
    final contextRef = useContext();

    final props = widget();
    final isEditMode = props.value.surveyId != null;

    final titleController = TextEditingController();
    final options = ref<List<SurveyOption>>([]);
    final isLoading = ref(false);

    // Load survey if in edit mode
    onMounted(() async {
      if (isEditMode) {
        isLoading.value = true;
        final survey = await surveysStore.fetchById(props.value.surveyId!);
        if (survey != null) {
          titleController.text = survey.title;
          options.value = List.from(survey.options);
        }
        isLoading.value = false;
      }
    });

    void addOption() {
      options.value = [
        ...options.value,
        SurveyOption(
          id: uuid.v4(),
          title: '',
          icon: 'check_circle',
          iconColor: 'blue',
          color: 'blue',
          votes: 0,
        ),
      ];
    }

    void removeOption(int index) {
      final newOptions = List<SurveyOption>.from(options.value);
      newOptions.removeAt(index);
      options.value = newOptions;
    }

    void updateOption(int index, SurveyOption updatedOption) {
      final newOptions = List<SurveyOption>.from(options.value);
      newOptions[index] = updatedOption;
      options.value = newOptions;
    }

    Future<void> save() async {
      if (titleController.text.trim().isEmpty) {
        return;
      }

      final schoolId = authStore.currentSchoolId;
      if (schoolId == null) {
        return;
      }

      isLoading.value = true;

      final data = {
        'title': titleController.text.trim(),
        'school': schoolId,
        'options': options.value.map((o) => o.toJson()).toList(),
      };

      final success = isEditMode
          ? await surveysStore.update(props.value.surveyId!, data)
          : await surveysStore.create(data);

      isLoading.value = false;

      if (success && contextRef.value?.mounted == true) {
        Navigator.of(contextRef.value!).pop();
      }
    }

    return (context) {
      final currentOptions = options.value;
      final loading = isLoading.value;

      return Scaffold(
        appBar: AppBar(
          title: Text(
            isEditMode ? 'Redigera Undersökning' : 'Skapa Undersökning',
          ),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Titel',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Alternativ',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...currentOptions.asMap().entries.map((entry) {
                      final index = entry.key;
                      final option = entry.value;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextField(
                                decoration: const InputDecoration(
                                  labelText: 'Alternativ titel',
                                  border: OutlineInputBorder(),
                                ),
                                controller: TextEditingController(
                                  text: option.title,
                                ),
                                onChanged: (value) {
                                  updateOption(
                                    index,
                                    SurveyOption(
                                      id: option.id,
                                      title: value,
                                      icon: option.icon,
                                      iconColor: option.iconColor,
                                      color: option.color,
                                      votes: option.votes,
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                initialValue: option.color,
                                decoration: const InputDecoration(
                                  labelText: 'Färg',
                                  border: OutlineInputBorder(),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'blue',
                                    child: Text('Blå'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'red',
                                    child: Text('Röd'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'green',
                                    child: Text('Grön'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'yellow',
                                    child: Text('Gul'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'purple',
                                    child: Text('Lila'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'orange',
                                    child: Text('Orange'),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    updateOption(
                                      index,
                                      SurveyOption(
                                        id: option.id,
                                        title: option.title,
                                        icon: option.icon,
                                        iconColor: value,
                                        color: value,
                                        votes: option.votes,
                                      ),
                                    );
                                  }
                                },
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: () => removeOption(index),
                                icon: const Icon(Icons.delete),
                                label: const Text('Ta bort'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: addOption,
                      icon: const Icon(Icons.add),
                      label: const Text('Lägg till alternativ'),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: save,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        isEditMode ? 'Uppdatera' : 'Skapa',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
      );
    };
  }
}
