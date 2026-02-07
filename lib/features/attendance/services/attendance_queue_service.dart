import 'dart:async';
import 'dart:collection';
import '../repositories/attendance_repository.dart';

class AttendanceEvent {
  final String cardId;
  final DateTime timestamp;
  int retryCount;

  AttendanceEvent({
    required this.cardId,
    required this.timestamp,
    this.retryCount = 0,
  });
}

class AttendanceQueueResult {
  final String studentName;
  final String action; // 'Checked In' or 'Checked Out'

  AttendanceQueueResult({required this.studentName, required this.action});
}

class AttendanceQueueService {
  final AttendanceRepository _repository;
  final _queue = Queue<AttendanceEvent>();
  Timer? _retryTimer;
  bool _processing = false;

  final _resultController = StreamController<AttendanceQueueResult>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  Stream<AttendanceQueueResult> get resultStream => _resultController.stream;
  Stream<String> get errorStream => _errorController.stream;

  static const _maxRetries = 5;
  static const _retryDelay = Duration(seconds: 10);

  AttendanceQueueService(this._repository);

  /// Enqueue a card scan for attendance processing.
  void enqueue(String cardId) {
    _queue.add(AttendanceEvent(cardId: cardId, timestamp: DateTime.now()));
    _processQueue();
  }

  Future<void> _processQueue() async {
    if (_processing || _queue.isEmpty) return;
    _processing = true;

    while (_queue.isNotEmpty) {
      final event = _queue.first;

      try {
        await _processEvent(event);
        _queue.removeFirst();
      } catch (e) {
        event.retryCount++;
        if (event.retryCount >= _maxRetries) {
          _errorController
              .add('Failed after $_maxRetries retries: ${event.cardId}');
          _queue.removeFirst();
        } else {
          _errorController.add(
            'Retry ${event.retryCount}/$_maxRetries for ${event.cardId}: $e',
          );
          // Move to back of queue and schedule retry
          _queue.removeFirst();
          _queue.add(event);
          _scheduleRetry();
          break;
        }
      }
    }

    _processing = false;
  }

  Future<void> _processEvent(AttendanceEvent event) async {
    final student = await _repository.findStudentByCardId(event.cardId);
    if (student == null) {
      _errorController.add('Unknown card: ${event.cardId}');
      return; // Don't retry unknown cards
    }

    // Try check-out first, then check-in
    final checkOut = await _repository.checkOut(student.id);
    if (checkOut != null) {
      _resultController.add(
        AttendanceQueueResult(studentName: student.name, action: 'Checked Out'),
      );
    } else {
      await _repository.checkIn(student.id);
      _resultController.add(
        AttendanceQueueResult(studentName: student.name, action: 'Checked In'),
      );
    }
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer(_retryDelay, () => _processQueue());
  }

  int get pendingCount => _queue.length;

  void dispose() {
    _retryTimer?.cancel();
    _resultController.close();
    _errorController.close();
  }
}
