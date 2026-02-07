import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/injection_keys.dart';
import '../services/ble_reader_service.dart';

class _LogEntry {
  final String message;
  final bool isError;
  final DateTime time;

  _LogEntry(this.message, {this.isError = false}) : time = DateTime.now();
}

class AttendancePage extends CompositionWidget {
  const AttendancePage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final bleService = inject(bleReaderServiceKey);
    final queueService = inject(attendanceQueueServiceKey);

    final bleState = ref(bleService.state);
    final log = ref<List<_LogEntry>>([]);
    final pendingCount = ref(0);

    void addLog(String message, {bool isError = false}) {
      log.value = [_LogEntry(message, isError: isError), ...log.value];
      if (log.value.length > 50) {
        log.value = log.value.sublist(0, 50);
      }
    }

    // Listen to BLE reader state
    bleService.stateStream.listen((state) {
      bleState.value = state;
      if (state == BleReaderState.connected) {
        addLog('Reader connected');
      } else if (state == BleReaderState.disconnected) {
        addLog('Reader disconnected', isError: true);
      }
    });

    // Listen to card scans from BLE reader
    bleService.cardIdStream.listen((cardId) {
      addLog('Card scanned: $cardId');
      queueService.enqueue(cardId);
      pendingCount.value = queueService.pendingCount;
    });

    // Listen to attendance results
    queueService.resultStream.listen((result) {
      addLog('${result.studentName} — ${result.action}');
      pendingCount.value = queueService.pendingCount;
    });

    // Listen to queue errors
    queueService.errorStream.listen((error) {
      addLog(error, isError: true);
      pendingCount.value = queueService.pendingCount;
    });

    return (context) {
      final state = bleState.value;

      return Scaffold(
        appBar: AppBar(
          title: const Text('Attendance'),
          actions: [
            IconButton(
              icon: Icon(
                _bleIcon(state),
                color: _bleColor(state),
              ),
              tooltip: 'NFC Reader Setup',
              onPressed: () => context.push('/reader-setup'),
            ),
          ],
        ),
        body: Column(
          children: [
            // BLE Reader status bar
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: _bleColor(state).withValues(alpha: 0.1),
              child: Row(
                children: [
                  Icon(_bleIcon(state), size: 20, color: _bleColor(state)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _bleLabel(state, bleService.connectedDevice),
                      style: TextStyle(
                        color: _bleColor(state),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (pendingCount.value > 0)
                    Chip(
                      label: Text('${pendingCount.value} pending'),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Attendance log
            Expanded(
              child: log.value.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.contactless_outlined,
                            size: 64,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            state == BleReaderState.connected
                                ? 'Ready — tap a card on the reader'
                                : 'Connect a BLE reader to start',
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: log.value.length,
                      itemBuilder: (context, index) {
                        final entry = log.value[index];
                        final timeStr =
                            '${entry.time.hour.toString().padLeft(2, '0')}:'
                            '${entry.time.minute.toString().padLeft(2, '0')}:'
                            '${entry.time.second.toString().padLeft(2, '0')}';

                        return ListTile(
                          dense: true,
                          leading: Icon(
                            entry.isError
                                ? Icons.error_outline
                                : Icons.check_circle_outline,
                            color: entry.isError ? Colors.red : Colors.green,
                            size: 20,
                          ),
                          title: Text(entry.message),
                          trailing: Text(
                            timeStr,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.grey),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      );
    };
  }

  static IconData _bleIcon(BleReaderState state) {
    switch (state) {
      case BleReaderState.connected:
        return Icons.bluetooth_connected;
      case BleReaderState.connecting:
      case BleReaderState.scanning:
        return Icons.bluetooth_searching;
      case BleReaderState.error:
        return Icons.bluetooth_disabled;
      case BleReaderState.disconnected:
        return Icons.bluetooth;
    }
  }

  static Color _bleColor(BleReaderState state) {
    switch (state) {
      case BleReaderState.connected:
        return Colors.green;
      case BleReaderState.connecting:
      case BleReaderState.scanning:
        return Colors.orange;
      case BleReaderState.error:
        return Colors.red;
      case BleReaderState.disconnected:
        return Colors.grey;
    }
  }

  static String _bleLabel(BleReaderState state, dynamic device) {
    switch (state) {
      case BleReaderState.connected:
        return 'Reader connected${device != null ? ': ${device.platformName}' : ''}';
      case BleReaderState.connecting:
        return 'Connecting to reader...';
      case BleReaderState.scanning:
        return 'Scanning for readers...';
      case BleReaderState.error:
        return 'Reader connection error — will retry';
      case BleReaderState.disconnected:
        return 'No reader connected';
    }
  }
}
