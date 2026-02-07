import 'package:pocketbase/pocketbase.dart';
import '../../../core/models/pocketbase_types.dart';

class AttendanceRepository {
  final PocketBase _pb;

  AttendanceRepository(this._pb);

  Future<Student?> findStudentByCardId(String cardId) async {
    try {
      final records = await _pb
          .collection('students')
          .getList(filter: 'cardId = "$cardId"', perPage: 1);

      if (records.items.isNotEmpty) {
        return Student.fromRecord(records.items.first);
      }
      return null;
    } catch (e) {
      // Log error or rethrow
      rethrow;
    }
  }

  Future<Registration> checkIn(String studentId) async {
    final now = DateTime.now().toIso8601String();

    // Look for active registration first?
    // Requirement is just check-in. Assuming new record for now.

    final body = {'student': studentId, 'checkedInAt': now};

    final record = await _pb.collection('registrations').create(body: body);
    return Registration.fromRecord(record);
  }

  Future<Registration?> checkOut(String studentId) async {
    final now = DateTime.now().toIso8601String();

    // Find latest open registration
    final records = await _pb
        .collection('registrations')
        .getList(
          filter: 'student = "$studentId" && checkedOutAt = ""',
          sort: '-created',
          perPage: 1,
        );

    if (records.items.isNotEmpty) {
      final reg = records.items.first;
      final updated = await _pb
          .collection('registrations')
          .update(reg.id, body: {'checkedOutAt': now});
      return Registration.fromRecord(updated);
    }
    return null; // No active registration found
  }
}
