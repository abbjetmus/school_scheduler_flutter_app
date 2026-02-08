import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../services/ble_reader_service.dart';

class ReaderSetupPage extends CompositionWidget {
  const ReaderSetupPage({super.key});

  static const String path = '/reader-setup';

  @override
  Widget Function(BuildContext) setup() {
    final bleService = inject(bleReaderServiceKey);

    final isScanning = ref(false);
    final scanResults = ref<List<ScanResult>>([]);
    final error = ref<String?>(null);
    final bleState = ref(bleService.state);

    // Listen to BLE state changes
    bleService.stateStream.listen((state) {
      bleState.value = state;
    });

    Future<void> startScan() async {
      error.value = null;
      isScanning.value = true;
      try {
        final results = await bleService.scanForReaders();
        scanResults.value = results;
      } catch (e) {
        error.value = e.toString();
      } finally {
        isScanning.value = false;
      }
    }

    Future<void> connectToDevice(BluetoothDevice device) async {
      error.value = null;
      try {
        await bleService.connect(device);
      } catch (e) {
        error.value = e.toString();
      }
    }

    return (context) {
      final state = bleState.value;

      return Scaffold(
        appBar: AppBar(
          title: const Text('NFC Reader Setup'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Connection status card
              Card(
                color: _stateColor(state).withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(
                        _stateIcon(state),
                        color: _stateColor(state),
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _stateLabel(state),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            if (state == BleReaderState.connected &&
                                bleService.connectedDevice != null)
                              Text(
                                bleService.connectedDevice!.platformName,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                      if (state == BleReaderState.connected)
                        TextButton(
                          onPressed: () => bleService.disconnect(),
                          child: const Text('Disconnect'),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Scan button
              FilledButton.icon(
                onPressed: isScanning.value ||
                        state == BleReaderState.connecting
                    ? null
                    : startScan,
                icon: isScanning.value
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.bluetooth_searching),
                label: Text(
                  isScanning.value ? 'Scanning...' : 'Scan for Readers',
                ),
              ),
              const SizedBox(height: 16),

              // Error display
              if (error.value != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    error.value!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),

              // Results list
              Text(
                'Nearby Devices',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const Divider(),
              Expanded(
                child: scanResults.value.isEmpty
                    ? Center(
                        child: Text(
                          isScanning.value
                              ? 'Searching...'
                              : 'Tap "Scan for Readers" to find nearby BLE devices',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.builder(
                        itemCount: scanResults.value.length,
                        itemBuilder: (context, index) {
                          final result = scanResults.value[index];
                          final device = result.device;
                          final isConnected =
                              state == BleReaderState.connected &&
                                  bleService.connectedDevice?.remoteId ==
                                      device.remoteId;

                          return ListTile(
                            leading: Icon(
                              Icons.bluetooth,
                              color: isConnected ? Colors.blue : Colors.grey,
                            ),
                            title: Text(
                              device.platformName.isNotEmpty
                                  ? device.platformName
                                  : 'Unknown Device',
                            ),
                            subtitle: Text(
                              '${device.remoteId} • RSSI: ${result.rssi} dBm',
                            ),
                            trailing: isConnected
                                ? const Chip(label: Text('Connected'))
                                : state == BleReaderState.connecting
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : null,
                            onTap: isConnected ||
                                    state == BleReaderState.connecting
                                ? null
                                : () => connectToDevice(device),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      );
    };
  }

  static Color _stateColor(BleReaderState state) {
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

  static IconData _stateIcon(BleReaderState state) {
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

  static String _stateLabel(BleReaderState state) {
    switch (state) {
      case BleReaderState.connected:
        return 'Reader Connected';
      case BleReaderState.connecting:
        return 'Connecting...';
      case BleReaderState.scanning:
        return 'Scanning...';
      case BleReaderState.error:
        return 'Connection Error';
      case BleReaderState.disconnected:
        return 'No Reader Connected';
    }
  }
}
