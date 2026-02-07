import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../calendar_store.dart';
import '../../../../core/models/pocketbase_types.dart';

class HaldorEventDetailsDialog extends StatelessWidget {
  final HaldorCalendarEvent event;
  final CalendarStore calendarStore;

  const HaldorEventDetailsDialog({
    super.key,
    required this.event,
    required this.calendarStore,
  });

  @override
  Widget build(BuildContext context) {
    final startTime = DateTime.parse(event.start);
    final endTime = DateTime.parse(event.end);

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.subjectCode ?? event.courseCode ?? 'Lektion',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${DateFormat('HH:mm').format(startTime)} - ${DateFormat('HH:mm').format(endTime)}',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        Text(
                          DateFormat('EEEE d MMMM yyyy', 'sv_SE').format(startTime),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Extra info chip (single string, not a list)
            if (event.extraInfo != null && event.extraInfo!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      label: Text(event.extraInfo!),
                      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                    ),
                  ],
                ),
              ),

            const Divider(height: 1),

            // Student list
            Expanded(
              child: FutureBuilder<List<StudentAttendance>>(
                future: calendarStore.fetchStudentsForHaldorEvent(
                  event.id,
                  event.attendance,
                  event.start,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Fel vid hämtning av studenter: ${snapshot.error}',
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        ),
                      ),
                    );
                  }

                  final students = snapshot.data ?? [];

                  if (students.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Inga studenter hittades för denna lektion'),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: students.length,
                    itemBuilder: (context, index) {
                      final student = students[index];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getAttendanceColor(student.lateMinutes, context),
                            child: Icon(
                              _getAttendanceIcon(student.lateMinutes),
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          title: Text(student.name),
                          subtitle: student.checkedInAt != null
                              ? Text(_formatCheckInTime(student.checkedInAt!))
                              : const Text('Ingen incheckning'),
                          trailing: student.lateMinutes != null
                              ? _buildLateChip(student.lateMinutes!, context)
                              : null,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getAttendanceColor(int? lateMinutes, BuildContext context) {
    if (lateMinutes == null) {
      return Colors.grey;
    } else if (lateMinutes <= 0) {
      return Colors.green;
    } else if (lateMinutes <= 10) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  IconData _getAttendanceIcon(int? lateMinutes) {
    if (lateMinutes == null) {
      return Icons.close;
    } else if (lateMinutes <= 0) {
      return Icons.check;
    } else if (lateMinutes <= 10) {
      return Icons.schedule;
    } else {
      return Icons.warning;
    }
  }

  String _formatCheckInTime(String checkInTime) {
    try {
      final dateTime = DateTime.parse(checkInTime);
      return 'Incheckad: ${DateFormat('HH:mm').format(dateTime)}';
    } catch (e) {
      return 'Incheckad: $checkInTime';
    }
  }

  Widget _buildLateChip(int lateMinutes, BuildContext context) {
    String text;
    Color color;

    if (lateMinutes <= 0) {
      text = 'I tid';
      color = Colors.green;
    } else if (lateMinutes <= 10) {
      text = '$lateMinutes min sen';
      color = Colors.orange;
    } else {
      text = '$lateMinutes min sen';
      color = Colors.red;
    }

    return Chip(
      label: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      backgroundColor: color,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}
