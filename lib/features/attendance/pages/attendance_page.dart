import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/injection_keys.dart';
import '../services/usb_reader_service.dart';

class _LogEntry {
  final String message;
  final bool isError;
  final DateTime time;

  _LogEntry(this.message, {this.isError = false}) : time = DateTime.now();
}

class AttendancePage extends CompositionWidget {
  const AttendancePage({super.key});

  static const String path = '/';

  @override
  Widget Function(BuildContext) setup() {
    final usbService = inject(usbReaderServiceKey);
    final queueService = inject(attendanceQueueServiceKey);

    final usbState = ref(usbService.state);
    final log = ref<List<_LogEntry>>([]);
    final pendingCount = ref(0);

    // Controller for manual card input
    final (cardInputController, textRef, valueRef) = useTextEditingController();
    final cardInputFocusNode = FocusNode();

    void addLog(String message, {bool isError = false}) {
      log.value = [_LogEntry(message, isError: isError), ...log.value];
      if (log.value.length > 50) {
        log.value = log.value.sublist(0, 50);
      }
    }

    // Handle card ID submitted via manual input
    void onCardInputSubmitted(String value) {
      final cardId = value.trim();
      if (cardId.isNotEmpty) {
        usbService.submitCardId(cardId);
      }
      cardInputController.clear();
      cardInputFocusNode.requestFocus();
    }

    // Listen to USB reader state
    usbService.stateStream.listen((state) {
      usbState.value = state;
      if (state == UsbReaderState.polling) {
        addLog('USB-läsare aktiv — väntar på kort');
      } else if (state == UsbReaderState.connected) {
        addLog('USB-läsare ansluten');
      } else if (state == UsbReaderState.disconnected) {
        addLog('USB-läsare frånkopplad', isError: true);
      }
    });

    // Listen to card scans from USB reader
    usbService.cardIdStream.listen((cardId) {
      addLog('Kort skannat: $cardId');
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

    onMounted(() async {
      // Auto-initialize and connect USB reader
      if (UsbReaderService.isSupported) {
        await usbService.initialize();
        final readers = await usbService.listReaders();
        if (readers.length == 1) {
          await usbService.connectToReader(readers.first);
        }
      }
      cardInputFocusNode.requestFocus();
    });

    onUnmounted(() {
      cardInputFocusNode.dispose();
    });

    return (context) {
      final state = usbState.value;

      return Scaffold(
        appBar: AppBar(
          title: const Text('Närvaro'),
          actions: [
            IconButton(
              icon: Icon(
                _readerIcon(state),
                color: _readerColor(state),
              ),
              tooltip: 'Kortläsare',
              onPressed: () => context.push('/reader-setup'),
            ),
          ],
        ),
        body: Column(
          children: [
            // Reader status bar
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: _readerColor(state).withValues(alpha: 0.1),
              child: Row(
                children: [
                  Icon(_readerIcon(state), size: 20, color: _readerColor(state)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _readerLabel(state, usbService.connectedReaderName),
                      style: TextStyle(
                        color: _readerColor(state),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (pendingCount.value > 0)
                    Chip(
                      label: Text('${pendingCount.value} väntande'),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Manual card input field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: cardInputController,
                focusNode: cardInputFocusNode,
                decoration: InputDecoration(
                  labelText: 'Kort-ID',
                  hintText: 'Lägg kortet på läsaren...',
                  prefixIcon: const Icon(Icons.contactless),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: () => onCardInputSubmitted(cardInputController.text),
                  ),
                  border: const OutlineInputBorder(),
                  helperText: state == UsbReaderState.polling
                      ? 'Läsare aktiv — kort-ID registreras automatiskt'
                      : 'Anslut en USB-läsare, eller ange kort-ID manuellt',
                ),
                onSubmitted: onCardInputSubmitted,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-fA-F0-9]')),
                ],
                autofocus: true,
              ),
            ),

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
                            state == UsbReaderState.polling
                                ? 'Redo — lägg kortet på läsaren'
                                : 'Anslut en USB-kortläsare för att börja',
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

  static IconData _readerIcon(UsbReaderState state) {
    switch (state) {
      case UsbReaderState.connected:
      case UsbReaderState.polling:
        return Icons.usb;
      case UsbReaderState.connecting:
        return Icons.usb;
      case UsbReaderState.error:
        return Icons.usb_off;
      case UsbReaderState.disconnected:
        return Icons.usb_off;
    }
  }

  static Color _readerColor(UsbReaderState state) {
    switch (state) {
      case UsbReaderState.connected:
      case UsbReaderState.polling:
        return Colors.green;
      case UsbReaderState.connecting:
        return Colors.orange;
      case UsbReaderState.error:
        return Colors.red;
      case UsbReaderState.disconnected:
        return Colors.grey;
    }
  }

  static String _readerLabel(UsbReaderState state, String? readerName) {
    switch (state) {
      case UsbReaderState.polling:
        return 'USB-läsare aktiv${readerName != null ? ': $readerName' : ''}';
      case UsbReaderState.connected:
        return 'USB-läsare ansluten${readerName != null ? ': $readerName' : ''}';
      case UsbReaderState.connecting:
        return 'Ansluter till USB-läsare...';
      case UsbReaderState.error:
        return 'USB-läsarfel';
      case UsbReaderState.disconnected:
        return 'Ingen USB-läsare ansluten';
    }
  }
}
