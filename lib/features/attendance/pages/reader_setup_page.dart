import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../services/nfc_reader_service.dart';
import '../services/usb_reader_service.dart';

class ReaderSetupPage extends CompositionWidget {
  const ReaderSetupPage({super.key});

  static const String path = '/reader-setup';

  @override
  Widget Function(BuildContext) setup() {
    final nfcService = inject(nfcReaderServiceKey);
    final usbService = inject(usbReaderServiceKey);

    final error = ref<String?>(null);
    final usbState = ref(usbService.state);
    final usbReaders = ref<List<String>>([]);
    final isSearchingUsb = ref(false);
    final lastCardId = ref<String?>(null);
    final nfcAvailable = ref(false);
    final nfcSessionActive = ref(false);
    final cardInputController = TextEditingController();
    final cardInputFocusNode = FocusNode();

    // Listen to USB reader state changes
    usbService.stateStream.listen((state) {
      usbState.value = state;
    });

    // Listen to card IDs from USB and NFC
    usbService.cardIdStream.listen((cardId) {
      lastCardId.value = cardId;
    });
    nfcService.cardIdStream.listen((cardId) {
      lastCardId.value = cardId;
    });
    nfcService.sessionActiveStream.listen((active) {
      nfcSessionActive.value = active;
    });

    onMounted(() async {
      // Check NFC availability on mobile
      nfcAvailable.value = await nfcService.isNfcAvailable();
      if (nfcAvailable.value) {
        await nfcService.startSession();
      }

      // Auto-scan for USB readers on desktop
      if (UsbReaderService.isSupported) {
        await usbService.initialize();
        final readers = await usbService.listReaders();
        usbReaders.value = readers;

        // Auto-connect if exactly one reader is found
        if (readers.length == 1) {
          await usbService.connectToReader(readers.first);
        }
      }

      if (!nfcAvailable.value) {
        Future.delayed(const Duration(milliseconds: 300), () {
          cardInputFocusNode.requestFocus();
        });
      }
    });

    onUnmounted(() {
      cardInputController.dispose();
      cardInputFocusNode.dispose();
      nfcService.stopSession();
    });

    Future<void> searchUsbReaders() async {
      error.value = null;
      isSearchingUsb.value = true;
      try {
        final readers = await usbService.listReaders();
        usbReaders.value = readers;
        if (readers.isEmpty) {
          error.value = 'Ingen USB-kortläsare hittades. Kontrollera att läsaren är ansluten.';
        }
      } catch (e) {
        error.value = e.toString();
      } finally {
        isSearchingUsb.value = false;
      }
    }

    void onCardInputSubmitted(String value) {
      final cardId = value.trim();
      if (cardId.isNotEmpty) {
        lastCardId.value = cardId;
        usbService.submitCardId(cardId);
      }
      cardInputController.clear();
      cardInputFocusNode.requestFocus();
    }

    return (context) {
      final currentUsbState = usbState.value;

      return Scaffold(
        appBar: AppBar(title: const Text('Kortläsare')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── USB Reader Section (desktop) ──
              if (UsbReaderService.isSupported) ...[
                Card(
                  color: _usbStateColor(currentUsbState).withValues(alpha: 0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.usb, color: _usbStateColor(currentUsbState), size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _usbStateLabel(currentUsbState),
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  if (currentUsbState == UsbReaderState.connected ||
                                      currentUsbState == UsbReaderState.polling)
                                    Text(
                                      usbService.connectedReaderName ?? '',
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                ],
                              ),
                            ),
                            if (currentUsbState == UsbReaderState.connected ||
                                currentUsbState == UsbReaderState.polling)
                              TextButton(
                                onPressed: () => usbService.disconnect(),
                                child: const Text('Koppla från'),
                              ),
                          ],
                        ),
                        if (currentUsbState == UsbReaderState.polling) ...[
                          const SizedBox(height: 12),
                          const Row(
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Väntar på kort — lägg kortet på läsaren...',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // USB reader list / scan button
                if (currentUsbState == UsbReaderState.disconnected) ...[
                  FilledButton.icon(
                    onPressed: isSearchingUsb.value ? null : searchUsbReaders,
                    icon: isSearchingUsb.value
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.usb),
                    label: Text(isSearchingUsb.value ? 'Söker...' : 'Sök USB-kortläsare'),
                  ),
                  const SizedBox(height: 8),
                  if (usbReaders.value.isNotEmpty)
                    ...usbReaders.value.map(
                      (reader) => ListTile(
                        leading: const Icon(Icons.credit_card),
                        title: Text(reader),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => usbService.connectToReader(reader),
                      ),
                    ),
                ],
                const SizedBox(height: 16),
              ],

              // ── NFC status card (mobile only) ──
              if (NfcReaderService.isNfcSupported) ...[
                Card(
                  color: nfcAvailable.value
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.orange.withValues(alpha: 0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Icon(Icons.nfc, color: nfcAvailable.value ? Colors.green : Colors.orange, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nfcAvailable.value ? 'Telefonens NFC är redo' : 'NFC ej tillgängligt',
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

              // ── Card test section ──
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Testa kortläsning', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      const Text(
                        'Kort-ID visas här när du skannar ett kort med USB-läsaren eller NFC.',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: cardInputController,
                        focusNode: cardInputFocusNode,
                        autofocus: !NfcReaderService.isNfcSupported,
                        decoration: InputDecoration(
                          labelText: 'Kort-ID (manuell inmatning)',
                          helperText: 'Ange kort-ID manuellt om det behövs',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.keyboard),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.send),
                            onPressed: () => onCardInputSubmitted(cardInputController.text),
                          ),
                        ),
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
                                    const Text(
                                      'Kort-ID mottaget!',
                                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                                    ),
                                    Text(
                                      lastCardId.value!,
                                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontFamily: 'monospace'),
                                    ),
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

              // ── Error display ──
              if (error.value != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(error.value!, style: const TextStyle(color: Colors.red)),
                ),

              // ── Troubleshooting ──
              ExpansionTile(
                title: const Text('Felsökning'),
                leading: const Icon(Icons.help_outline),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (UsbReaderService.isSupported) ...[
                          Text('USB-läsaren hittas inte?', style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 8),
                          const Text('• Kontrollera att läsaren är ansluten till en USB-port'),
                          const Text('• Prova en annan USB-port'),
                          const Text('• Koppla ur och koppla in läsaren igen'),
                          const Text('• Kontrollera att LED-lampan lyser på läsaren'),
                          const Text('• macOS: Inga drivrutiner behövs (inbyggt stöd)'),
                          const Text('• Windows: Inga extra drivrutiner behövs normalt'),
                          const SizedBox(height: 12),
                          Text('Kort-ID läses inte?', style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 8),
                          const Text('• Lägg kortet plant på läsaren'),
                          const Text('• Håll kortet stilla en sekund'),
                          const Text('• Kontrollera att kortet är ISO 14443 (MIFARE/NFC)'),
                          const Text('• Prova med ett annat kort'),
                          const SizedBox(height: 12),
                        ],
                        if (NfcReaderService.isNfcSupported) ...[
                          Text('NFC fungerar inte?', style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 8),
                          const Text('• Kontrollera att NFC är aktiverat i inställningar'),
                          const Text('• Håll kortet stilla mot telefonens baksida'),
                          const Text('• Prova att ta bort telefonskalet'),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    };
  }

  static Color _usbStateColor(UsbReaderState state) {
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

  static String _usbStateLabel(UsbReaderState state) {
    switch (state) {
      case UsbReaderState.polling:
        return 'USB-läsare aktiv';
      case UsbReaderState.connected:
        return 'USB-läsare ansluten';
      case UsbReaderState.connecting:
        return 'Ansluter...';
      case UsbReaderState.error:
        return 'USB-läsarfel';
      case UsbReaderState.disconnected:
        return 'Ingen USB-läsare ansluten';
    }
  }
}
