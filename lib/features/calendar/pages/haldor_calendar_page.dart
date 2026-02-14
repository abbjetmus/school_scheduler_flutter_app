import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:intl/intl.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/models/pocketbase_types.dart';
import 'components/haldor_event_details_dialog.dart';

class HaldorCalendarPage extends CompositionWidget {
  const HaldorCalendarPage({super.key});

  static const String path = '/haldor-calendar';

  @override
  Widget Function(BuildContext) setup() {
    final calendarStore = inject(calendarStoreKey);
    final classesStore = inject(classesStoreKey);

    // State
    final selectedClass = ref<ClassGroup?>(null);
    final startDate = ref<DateTime>(_getStartOfWeek());
    final endDate = ref<DateTime>(_getEndOfWeek());
    final calendarView = ref<CalendarView>(CalendarView.week);

    // CalendarController for programmatic view switching
    final calendarController = CalendarController();
    calendarController.view = CalendarView.week;

    // Sync controller when calendarView ref changes
    watch(() => calendarView.value, (newView, _) {
      calendarController.view = newView;
    });

    // Fetch classes on init
    onMounted(() {
      classesStore.getClasses();
    });

    return (BuildContext context) {
      final classes = classesStore.classes.value;
      final classesWithExtraInfo = classes.where((c) => c.extraInfo.isNotEmpty).toList();
      final haldorEvents = calendarStore.haldorEvents.value;
      final loading = calendarStore.loading.value;

      return Scaffold(
        appBar: AppBar(title: const Text('Haldor Kalender')),
        body: Column(
          children: [
            // Filters section
            Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Class dropdown
                    DropdownButtonFormField<ClassGroup>(
                      initialValue: selectedClass.value,
                      decoration: const InputDecoration(labelText: 'Välj klass', border: OutlineInputBorder()),
                      items: classesWithExtraInfo.map((classGroup) {
                        return DropdownMenuItem(value: classGroup, child: Text(classGroup.name ?? ''));
                      }).toList(),
                      onChanged: (value) {
                        selectedClass.value = value;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Date range pickers
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: startDate.value,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );
                              if (date != null) {
                                startDate.value = date;
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(labelText: 'Startdatum', border: OutlineInputBorder()),
                              child: Text(DateFormat('yyyy-MM-dd').format(startDate.value)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: endDate.value,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );
                              if (date != null) {
                                endDate.value = date;
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(labelText: 'Slutdatum', border: OutlineInputBorder()),
                              child: Text(DateFormat('yyyy-MM-dd').format(endDate.value)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Fetch button
                    ElevatedButton(
                      onPressed: selectedClass.value == null || loading
                          ? null
                          : () {
                              final start = DateTime(startDate.value.year, startDate.value.month, startDate.value.day);
                              final end = DateTime(
                                endDate.value.year,
                                endDate.value.month,
                                endDate.value.day,
                                23,
                                59,
                                59,
                              );
                              debugPrint(
                                'HaldorCalendarPage: Fetching with class=${selectedClass.value?.name}, extraInfo=${selectedClass.value?.extraInfo}',
                              );
                              debugPrint(
                                'HaldorCalendarPage: start=${start.toIso8601String()}, end=${end.toIso8601String()}',
                              );
                              calendarStore.fetchHaldorCalendarEventsFromDb(
                                selectedClass.value!.extraInfo,
                                start.toIso8601String(),
                                end.toIso8601String(),
                              );
                            },
                      child: loading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Hämta'),
                    ),
                  ],
                ),
              ),
            ),

            // Calendar view toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SegmentedButton<CalendarView>(
                    segments: const [
                      ButtonSegment(value: CalendarView.day, label: Text('Dag')),
                      ButtonSegment(value: CalendarView.week, label: Text('Vecka')),
                      ButtonSegment(value: CalendarView.month, label: Text('Månad')),
                    ],
                    selected: {calendarView.value},
                    onSelectionChanged: (Set<CalendarView> selected) {
                      calendarView.value = selected.first;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Calendar
            Expanded(
              child: Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SfCalendar(
                  controller: calendarController,
                  view: calendarView.value,
                  firstDayOfWeek: 1, // Monday
                  dataSource: _HaldorEventDataSource(haldorEvents),
                  monthViewSettings: const MonthViewSettings(
                    appointmentDisplayMode: MonthAppointmentDisplayMode.appointment,
                  ),
                  timeSlotViewSettings: const TimeSlotViewSettings(startHour: 7, endHour: 18, timeFormat: 'HH:mm'),
                  onTap: (CalendarTapDetails details) {
                    if (details.appointments != null && details.appointments!.isNotEmpty) {
                      final appointment = details.appointments!.first as Appointment;
                      final event = appointment.id as HaldorCalendarEvent;

                      showDialog(
                        context: context,
                        builder: (context) => HaldorEventDetailsDialog(event: event, calendarStore: calendarStore),
                      );
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      );
    };
  }

  static DateTime _getStartOfWeek() {
    final now = DateTime.now();
    final weekday = now.weekday;
    return now.subtract(Duration(days: weekday - 1));
  }

  static DateTime _getEndOfWeek() {
    final now = DateTime.now();
    final weekday = now.weekday;
    return now.add(Duration(days: 7 - weekday));
  }
}

class _HaldorEventDataSource extends CalendarDataSource {
  _HaldorEventDataSource(List<HaldorCalendarEvent> events) {
    debugPrint('_HaldorEventDataSource: Creating data source with ${events.length} events');
    appointments = events.map((event) {
      final startTime = DateTime.parse(event.start);
      final endTime = DateTime.parse(event.end);
      final subject = event.subjectCode ?? event.courseCode ?? 'Lektion';
      debugPrint('_HaldorEventDataSource: event id=${event.id}, subject=$subject, start=$startTime, end=$endTime');
      return Appointment(
        startTime: startTime,
        endTime: endTime,
        subject: subject,
        color: _getColorForSubject(event.subjectCode ?? event.courseCode ?? ''),
        id: event,
      );
    }).toList();
    debugPrint('_HaldorEventDataSource: Created ${appointments?.length} appointments');
  }

  Color _getColorForSubject(String subject) {
    if (subject.isEmpty) return Colors.blue;

    // Generate a consistent color based on subject code
    final hash = subject.hashCode;
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.cyan,
      Colors.amber,
      Colors.deepOrange,
    ];

    return colors[hash.abs() % colors.length];
  }
}
