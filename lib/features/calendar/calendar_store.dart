import 'package:flutter/foundation.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart';
import '../../core/models/pocketbase_types.dart';

class StudentAttendance {
  final String id;
  final String name;
  final String? checkedInAt;
  final String? checkedOutAt;
  final int? lateMinutes;

  StudentAttendance({required this.id, required this.name, this.checkedInAt, this.checkedOutAt, this.lateMinutes});
}

class CalendarStore {
  final PocketBase _pb;

  CalendarStore(this._pb);

  final _haldorEvents = ref<List<HaldorCalendarEvent>>([]);
  final _students = ref<List<StudentAttendance>>([]);
  final _loading = ref<bool>(false);
  final _showCalendarView = ref<bool>(false);

  Ref<List<HaldorCalendarEvent>> get haldorEvents => _haldorEvents;
  Ref<List<StudentAttendance>> get students => _students;
  Ref<bool> get loading => _loading;
  Ref<bool> get showCalendarView => _showCalendarView;

  Future<List<HaldorCalendarEvent>> fetchHaldorCalendarEventsFromDb(
    List<String> extraInfoValues,
    String startDateTime,
    String endDateTime,
  ) async {
    _loading.value = true;
    try {
      final extraInfoFilter = extraInfoValues.map((val) => 'extraInfo = "$val"').join(' || ');
      final dateFilter = 'start >= "$startDateTime" && end <= "$endDateTime"';
      final fullFilter = '($extraInfoFilter) && $dateFilter';

      debugPrint('CalendarStore: extraInfoValues = $extraInfoValues');
      debugPrint('CalendarStore: startDateTime = $startDateTime');
      debugPrint('CalendarStore: endDateTime = $endDateTime');
      debugPrint('CalendarStore: fullFilter = $fullFilter');

      final records = await _pb
          .collection(Collections.haldorCalendarEvents)
          .getFullList(filter: fullFilter, sort: 'start');

      debugPrint('CalendarStore: fetched ${records.length} records from PocketBase');
      for (final r in records) {
        debugPrint(
          'CalendarStore: event id=${r.id}, start=${r.data['start']}, end=${r.data['end']}, extraInfo=${r.data['extraInfo']}, subjectCode=${r.data['subjectCode']}',
        );
      }

      final events = records.map((r) => HaldorCalendarEvent.fromRecord(r)).toList();
      _haldorEvents.value = events;
      _showCalendarView.value = true;

      debugPrint('CalendarStore: _haldorEvents.value now has ${_haldorEvents.value.length} events');

      return events;
    } catch (e) {
      debugPrint('CalendarStore: Error fetching Haldor events: $e');
      rethrow;
    } finally {
      _loading.value = false;
    }
  }

  Future<List<StudentAttendance>> fetchStudentsForHaldorEvent(
    String haldorEventId,
    List<String> attendance,
    String eventStartTime,
  ) async {
    _loading.value = true;
    try {
      if (attendance.isEmpty) {
        _students.value = [];
        return [];
      }

      final studentFilter = attendance.map((id) => 'haldorStudentId = "$id"').join(' || ');
      final studentRecords = await _pb.collection(Collections.students).getFullList(filter: studentFilter);

      final registrationRecords = await _pb
          .collection(Collections.registrations)
          .getFullList(filter: 'haldorCalendarEvent = "$haldorEventId"');

      final registrationsByStudent = <String, Registration>{};
      for (final r in registrationRecords) {
        final reg = Registration.fromRecord(r);
        registrationsByStudent[reg.studentId] = reg;
      }

      final eventStart = DateTime.tryParse(eventStartTime);

      final studentData = studentRecords.map((record) {
        final student = Student.fromRecord(record);
        final reg = registrationsByStudent[student.id];
        int? lateMinutes;

        if (reg?.checkedInAt != null && eventStart != null) {
          final checkedIn = DateTime.tryParse(reg!.checkedInAt!);
          if (checkedIn != null) {
            final diffMs = checkedIn.millisecondsSinceEpoch - eventStart.millisecondsSinceEpoch;
            lateMinutes = (diffMs / 60000).floor();
            if (lateMinutes < 0) lateMinutes = 0;
          }
        }

        return StudentAttendance(
          id: student.id,
          name: student.name,
          checkedInAt: reg?.checkedInAt,
          checkedOutAt: reg?.checkedOutAt,
          lateMinutes: lateMinutes,
        );
      }).toList();

      _students.value = studentData;
      return studentData;
    } catch (e) {
      debugPrint('CalendarStore: Error fetching students for event: $e');
      _students.value = [];
      return [];
    } finally {
      _loading.value = false;
    }
  }

  void clearCalendarData() {
    _haldorEvents.value = [];
    _showCalendarView.value = false;
  }
}
