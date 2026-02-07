import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:uuid/uuid.dart';
import '../../../core/di/injection_keys.dart';

class CreateSubscriptionPage extends CompositionWidget {
  final String? subscriptionId;

  const CreateSubscriptionPage({super.key, this.subscriptionId});

  @override
  Widget Function(BuildContext) setup() {
    final subscriptionsStore = inject(subscriptionsStoreKey);
    final authStore = inject(authStoreKey);
    final contextRef = useContext();

    final props = widget();
    final isEditMode = props.value.subscriptionId != null;

    final titleController = TextEditingController();
    final calendarEvents = ref<List<_CalendarEventData>>([]);
    final notificationLeadMinutes = ref<List<int>>([]);
    final isLoading = ref<bool>(false);

    // Load existing subscription if editing
    onMounted(() async {
      if (isEditMode) {
        isLoading.value = true;
        final subscription = await subscriptionsStore.fetchById(props.value.subscriptionId!);
        if (subscription != null) {
          titleController.text = subscription.title ?? '';
          calendarEvents.value = subscription.calendarEvents
              .map((e) => _CalendarEventData(
                    id: e.id,
                    title: e.title,
                    start: DateTime.tryParse(e.start) ?? DateTime.now(),
                    end: DateTime.tryParse(e.end) ?? DateTime.now(),
                  ))
              .toList();
          notificationLeadMinutes.value = subscription.eventNotificationLeadMinutes
              .map((e) => e.minutesBeforeEvent)
              .toList();
        }
        isLoading.value = false;
      }
    });

    void addCalendarEvent() {
      final now = DateTime.now();
      calendarEvents.value = [
        ...calendarEvents.value,
        _CalendarEventData(
          id: const Uuid().v4(),
          title: '',
          start: now,
          end: now.add(const Duration(hours: 1)),
        ),
      ];
    }

    void removeCalendarEvent(int index) {
      final events = [...calendarEvents.value];
      events.removeAt(index);
      calendarEvents.value = events;
    }

    void updateCalendarEvent(int index, _CalendarEventData event) {
      final events = [...calendarEvents.value];
      events[index] = event;
      calendarEvents.value = events;
    }

    void addNotificationLeadTime() {
      notificationLeadMinutes.value = [...notificationLeadMinutes.value, 15];
    }

    void removeNotificationLeadTime(int index) {
      final leads = [...notificationLeadMinutes.value];
      leads.removeAt(index);
      notificationLeadMinutes.value = leads;
    }

    void updateNotificationLeadTime(int index, int minutes) {
      final leads = [...notificationLeadMinutes.value];
      leads[index] = minutes;
      notificationLeadMinutes.value = leads;
    }

    Future<void> save() async {
      final title = titleController.text.trim();
      if (title.isEmpty) {
        if (contextRef.value?.mounted == true) {
          ScaffoldMessenger.of(contextRef.value!).showSnackBar(
            const SnackBar(content: Text('Titel krävs')),
          );
        }
        return;
      }

      final schoolId = authStore.currentSchoolId;
      if (schoolId == null) {
        if (contextRef.value?.mounted == true) {
          ScaffoldMessenger.of(contextRef.value!).showSnackBar(
            const SnackBar(content: Text('Ingen skola vald')),
          );
        }
        return;
      }

      final data = {
        'title': title,
        'school': schoolId,
        'calendarEvents': calendarEvents.value.map((e) => e.toJson()).toList(),
        'eventNotificationLeadMinutes': notificationLeadMinutes.value
            .map((minutes) => {
                  'id': const Uuid().v4(),
                  'minutesBeforeEvent': minutes,
                })
            .toList(),
      };

      isLoading.value = true;
      bool success;
      if (isEditMode) {
        success = await subscriptionsStore.update(props.value.subscriptionId!, data);
      } else {
        success = await subscriptionsStore.create(data);
      }
      isLoading.value = false;

      if (success) {
        if (contextRef.value?.mounted == true) {
          ScaffoldMessenger.of(contextRef.value!).showSnackBar(
            SnackBar(
              content: Text(
                isEditMode
                    ? 'Prenumeration uppdaterad'
                    : 'Prenumeration skapad',
              ),
            ),
          );
          Navigator.of(contextRef.value!).pop();
        }
      } else {
        if (contextRef.value?.mounted == true) {
          ScaffoldMessenger.of(contextRef.value!).showSnackBar(
            const SnackBar(content: Text('Kunde inte spara prenumeration')),
          );
        }
      }
    }

    return (context) {
      if (isLoading.value) {
        return Scaffold(
          appBar: AppBar(
            title: Text(isEditMode ? 'Redigera Prenumeration' : 'Skapa Prenumeration'),
          ),
          body: const Center(child: CircularProgressIndicator()),
        );
      }

      return Scaffold(
        appBar: AppBar(
          title: Text(isEditMode ? 'Redigera Prenumeration' : 'Skapa Prenumeration'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title field
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Titel',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              // Calendar Events section
              Text(
                'Kalenderhändelser',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...List.generate(calendarEvents.value.length, (index) {
                final event = calendarEvents.value[index];
                return _CalendarEventCard(
                  event: event,
                  onUpdate: (updated) => updateCalendarEvent(index, updated),
                  onRemove: () => removeCalendarEvent(index),
                );
              }),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: addCalendarEvent,
                icon: const Icon(Icons.add),
                label: const Text('Lägg till händelse'),
              ),
              const SizedBox(height: 24),

              // Notification lead times section
              Text(
                'Notifieringstider',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...List.generate(notificationLeadMinutes.value.length, (index) {
                final minutes = notificationLeadMinutes.value[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: 'Minuter före händelse',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            controller: TextEditingController(text: minutes.toString())
                              ..selection = TextSelection.collapsed(
                                offset: minutes.toString().length,
                              ),
                            onChanged: (value) {
                              final parsed = int.tryParse(value);
                              if (parsed != null) {
                                updateNotificationLeadTime(index, parsed);
                              }
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => removeNotificationLeadTime(index),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: addNotificationLeadTime,
                icon: const Icon(Icons.add),
                label: const Text('Lägg till notifieringstid'),
              ),
              const SizedBox(height: 32),

              // Save button
              ElevatedButton(
                onPressed: save,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(isEditMode ? 'Uppdatera' : 'Skapa'),
              ),
            ],
          ),
        ),
      );
    };
  }
}

class _CalendarEventData {
  final String id;
  String title;
  DateTime start;
  DateTime end;

  _CalendarEventData({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'start': start.toIso8601String(),
      'end': end.toIso8601String(),
    };
  }
}

class _CalendarEventCard extends StatelessWidget {
  final _CalendarEventData event;
  final Function(_CalendarEventData) onUpdate;
  final VoidCallback onRemove;

  const _CalendarEventCard({
    required this.event,
    required this.onUpdate,
    required this.onRemove,
  });

  Future<void> _pickDateTime(BuildContext context, bool isStart) async {
    final currentDateTime = isStart ? event.start : event.end;

    final date = await showDatePicker(
      context: context,
      initialDate: currentDateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (date == null) return;

    if (!context.mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(currentDateTime),
    );

    if (time == null) return;

    final newDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    if (isStart) {
      onUpdate(_CalendarEventData(
        id: event.id,
        title: event.title,
        start: newDateTime,
        end: event.end,
      ));
    } else {
      onUpdate(_CalendarEventData(
        id: event.id,
        title: event.title,
        start: event.start,
        end: newDateTime,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Händelsetitel',
                border: OutlineInputBorder(),
              ),
              controller: TextEditingController(text: event.title)
                ..selection = TextSelection.collapsed(offset: event.title.length),
              onChanged: (value) {
                onUpdate(_CalendarEventData(
                  id: event.id,
                  title: value,
                  start: event.start,
                  end: event.end,
                ));
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDateTime(context, true),
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(
                      'Start: ${_formatDateTime(event.start)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDateTime(context, false),
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(
                      'Slut: ${_formatDateTime(event.end)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onRemove,
                icon: const Icon(Icons.delete),
                label: const Text('Ta bort'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
