import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../calendar_store.dart';
import '../../../../core/models/pocketbase_types.dart';

class HaldorEventDetailsDialog extends StatefulWidget {
  final HaldorCalendarEvent event;
  final CalendarStore calendarStore;

  const HaldorEventDetailsDialog({
    super.key,
    required this.event,
    required this.calendarStore,
  });

  @override
  State<HaldorEventDetailsDialog> createState() => _HaldorEventDetailsDialogState();
}

class _HaldorEventDetailsDialogState extends State<HaldorEventDetailsDialog> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  late Future<List<StudentAttendance>> _studentsFuture;

  @override
  void initState() {
    super.initState();
    _studentsFuture = widget.calendarStore.fetchStudentsForHaldorEvent(
      widget.event.id,
      widget.event.attendance,
      widget.event.start,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<StudentAttendance> _filterStudents(List<StudentAttendance> students) {
    if (_searchQuery.isEmpty) return students;
    final query = _searchQuery.toLowerCase();
    return students.where((s) => s.name.toLowerCase().contains(query)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final startTime = DateTime.parse(widget.event.start);
    final endTime = DateTime.parse(widget.event.end);

    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.event.subjectCode ?? widget.event.courseCode ?? 'Lektion',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                '${DateFormat('HH:mm').format(startTime)} - ${DateFormat('HH:mm').format(endTime)}  •  ${DateFormat('EEEE d MMMM yyyy', 'sv_SE').format(startTime)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Extra info chip
            if (widget.event.extraInfo != null && widget.event.extraInfo!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      label: Text(widget.event.extraInfo!),
                      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                    ),
                  ],
                ),
              ),

            // Search field
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Sök elev',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),

            const Divider(height: 1),

            // Student list
            Expanded(
              child: FutureBuilder<List<StudentAttendance>>(
                future: _studentsFuture,
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

                  final allStudents = snapshot.data ?? [];
                  final students = _filterStudents(allStudents);

                  if (allStudents.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Inga studenter hittades för denna lektion'),
                      ),
                    );
                  }

                  if (students.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Inga elever matchar sökningen'),
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
                            backgroundColor: _getAttendanceColor(student.lateMinutes),
                            child: Icon(
                              _getAttendanceIcon(student.lateMinutes),
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          title: Text(student.name),
                          subtitle: Text(_formatAttendanceTimes(student)),
                          trailing: student.lateMinutes != null
                              ? _buildLateChip(student.lateMinutes!)
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

  Color _getAttendanceColor(int? lateMinutes) {
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

  String _formatAttendanceTimes(StudentAttendance student) {
    final parts = <String>[];

    if (student.checkedInAt != null) {
      try {
        final dateTime = DateTime.parse(student.checkedInAt!);
        parts.add('In: ${DateFormat('HH:mm').format(dateTime)}');
      } catch (_) {
        parts.add('In: ${student.checkedInAt}');
      }
    }

    if (student.checkedOutAt != null) {
      try {
        final dateTime = DateTime.parse(student.checkedOutAt!);
        parts.add('Ut: ${DateFormat('HH:mm').format(dateTime)}');
      } catch (_) {
        parts.add('Ut: ${student.checkedOutAt}');
      }
    }

    if (parts.isEmpty) return 'Ingen incheckning';
    return parts.join('  •  ');
  }

  Widget _buildLateChip(int lateMinutes) {
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
