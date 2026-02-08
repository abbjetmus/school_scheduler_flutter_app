import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../services/ble_reader_service.dart';
import '../services/nfc_reader_service.dart';

class ReaderSetupPage extends CompositionWidget {
  const ReaderSetupPage({super.key});

  static const String path = '/reader-setup';

  @override
  Widget Function(BuildContext) setup() {
    final bleService = inject(bleReaderServiceKey);
    final nfcService = inject(nfcReaderServiceKey);

    final isScanning = ref(false);
    final scanResults = ref<List<ScanResult>>([]);
    final error = ref<String?>(null);
    final bleState = ref(bleService.state);
    final lastCardId = ref<String?>(null);
    final nfcAvailable = ref(false);
    final nfcSessionActive = ref(false);
    final cardInputController = TextEditingController();
    final cardInputFocusNode = FocusNode();

    // Listen to BLE state changes
    bleService.stateStream.listen((state) {
      bleState.value = state;
    });

    // Listen to card IDs from both BLE and NFC
    bleService.cardIdStream.listen((cardId) {
      lastCardId.value = cardId;
    });
    nfcService.cardIdStream.listen((cardId) {
      lastCardId.value = cardId;
    });
    nfcService.sessionActiveStream.listen((active) {
      nfcSessionActive.value = active;
    });

    // Check NFC availability on mount
    onMounted(() async {
      nfcAvailable.value = await nfcService.isNfcAvailable();
      if (nfcAvailable.value) {
        // Auto-start NFC session on mobile
        await nfcService.startSession();
      }
    });

    onUnmounted(() {
      cardInputController.dispose();
      cardInputFocusNode.dispose();
      nfcService.stopSession();
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

    void onCardInputSubmitted(String value) {
      final cardId = value.trim();
      if (cardId.isNotEmpty) {
        nfcService.submitCardId(cardId);
      }
      cardInputController.clear();
      cardInputFocusNode.requestFocus();
    }

    return (context) {
      final state = bleState.value;

      return Scaffold(
        appBar: AppBar(title: const Text('NFC Reader Setup')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // NFC status card (mobile only)
              if (NfcReaderService.isNfcSupported) ...[
                Card(
                  color: nfcAvailable.value
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.orange.withValues(alpha: 0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.nfc,
                          color: nfcAvailable.value ? Colors.green : Colors.orange,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nfcAvailable.value
                                    ? 'Telefonens NFC är redo'
                                    : 'NFC ej tillgängligt',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                nfcAvailable.value
                                    ? nfcSessionActive.value
                                        ? 'Håll kortet mot telefonen för att skanna'
                                        : 'NFC-session ej aktiv'
                                    : 'Aktivera NFC i telefonens inställningar',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        if (nfcAvailable.value)
                          TextButton(
                            onPressed: () async {
                              if (nfcSessionActive.value) {
                                await nfcService.stopSession();
                              } else {
                                await nfcService.startSession();
                              }
                            },
                            child: Text(nfcSessionActive.value ? 'Stoppa' : 'Starta'),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // BLE connection status card
              Card(
                color: _stateColor(state).withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(_stateIcon(state), color: _stateColor(state), size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _stateLabel(state),
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            if (state == BleReaderState.connected && bleService.connectedDevice != null)
                              Text(
                                bleService.connectedDevice!.platformName,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                      if (state == BleReaderState.connected)
                        TextButton(onPressed: () => bleService.disconnect(), child: const Text('Koppla från')),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Card test section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Testa kortläsning', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(
                        NfcReaderService.isNfcSupported
                            ? 'Håll kortet mot telefonens NFC-läsare, eller skriv in kort-ID manuellt.'
                            : 'Anslut läsaren via USB till datorn och klicka i fältet nedan. '
                              'Skanna ett kort — om läsaren fungerar som USB-tangentbord '
                              'visas kort-ID:t automatiskt.',
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: cardInputController,
                        focusNode: cardInputFocusNode,
                        decoration: InputDecoration(
                          labelText: 'Kort-ID (manuell inmatning)',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.nfc),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.send),
                            onPressed: () => onCardInputSubmitted(cardInputController.text),
                          ),
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F]')),
                        ],
                        onSubmitted: onCardInputSubmitted,
                      ),
                      const SizedBox(height: 12),
                      if (lastCardId.value != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Kort-ID mottaget!', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                    Text(lastCardId.value!, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontFamily: 'monospace')),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Troubleshooting tips
              ExpansionTile(
                title: const Text('Felsökning'),
                leading: const Icon(Icons.help_outline),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (NfcReaderService.isNfcSupported) ...[
                          Text('NFC fungerar inte?', style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 8),
                          const Text('• Kontrollera att NFC är aktiverat i inställningar'),
                          const Text('• Håll kortet stilla mot telefonens baksida'),
                          const Text('• Prova att ta bort telefonskalet'),
                          const Text('• Stöder kortet NFC? (13.56 MHz IC-kort)'),
                          const SizedBox(height: 12),
                        ],
                        Text('BLE-läsaren hittas inte?', style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 8),
                        const Text('• Starta om NFC-läsaren (koppla ur och in USB)'),
                        const Text('• Flytta närmare läsaren (1-2 meter)'),
                        const Text('• Koppla från andra Bluetooth-enheter'),
                        const Text('• Aktivera Plats/GPS (Android)'),
                        const Text('• Prova att ansluta till "Unknown Device"'),
                        const SizedBox(height: 12),
                        Text('Kort-ID visas inte?', style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 8),
                        const Text('• Anslut läsaren till datorns USB-port (inte bara laddare)'),
                        const Text('• Klicka i textfältet ovan och skanna ett kort'),
                        const Text('• Testa i Anteckningar först — skannar kortet text?'),
                        const Text('• Prova med en annan typ av kort'),
                        const Text('• Lägg inte läsaren på metallyta'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Scan button
              FilledButton.icon(
                onPressed: isScanning.value || state == BleReaderState.connecting ? null : startScan,
                icon: isScanning.value
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.bluetooth_searching),
                label: Text(isScanning.value ? 'Söker...' : 'Sök efter BLE-läsare'),
              ),
              const SizedBox(height: 16),

              // Error display
              if (error.value != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(error.value!, style: const TextStyle(color: Colors.red)),
                ),

              // Results list
              Text('Enheter i närheten', style: Theme.of(context).textTheme.titleSmall),
              if (scanResults.value.isNotEmpty && !isScanning.value)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'Tips: Din NFC-läsare kan visas som "Unknown Device". Prova att ansluta till enheter med stark signal (RSSI > -70 dBm)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600], fontStyle: FontStyle.italic),
                  ),
                ),
              const Divider(),
              ...scanResults.value.map((result) {
                final device = result.device;
                final isConnected =
                    state == BleReaderState.connected &&
                    bleService.connectedDevice?.remoteId == device.remoteId;

                final signalColor = result.rssi > -60
                    ? Colors.green
                    : result.rssi > -75
                    ? Colors.orange
                    : Colors.red;

                return ListTile(
                  leading: Icon(Icons.bluetooth, color: isConnected ? Colors.blue : signalColor),
                  title: Text(
                    device.platformName.isNotEmpty ? device.platformName : 'Unknown Device',
                    style: device.platformName.isEmpty
                        ? TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic)
                        : null,
                  ),
                  subtitle: Text('${device.remoteId}\nSignal: ${result.rssi} dBm'),
                  isThreeLine: true,
                  trailing: isConnected
                      ? const Chip(label: Text('Ansluten'))
                      : state == BleReaderState.connecting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                  onTap: isConnected || state == BleReaderState.connecting
                      ? null
                      : () => connectToDevice(device),
                );
              }),
              if (scanResults.value.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    isScanning.value ? 'Söker...' : 'Tryck på "Sök efter BLE-läsare" för att hitta enheter',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                    textAlign: TextAlign.center,
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
        return 'BLE-läsare ansluten';
      case BleReaderState.connecting:
        return 'Ansluter...';
      case BleReaderState.scanning:
        return 'Söker...';
      case BleReaderState.error:
        return 'Anslutningsfel';
      case BleReaderState.disconnected:
        return 'Ingen BLE-läsare ansluten';
    }
  }
}
