import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';

import '../../core/di/injection_keys.dart';
import '../../core/pocketbase/pocketbase_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../kiosk/kiosk_settings_card.dart';
import '../reader/pcsc_reader_service.dart';

/// Läsare, ljud och utloggning av låntagaren. Sparas på den här datorn.
class SettingsPage extends CompositionWidget {
  const SettingsPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final hub = inject(readerHubKey);
    final auth = inject(authStoreKey);

    final readers = ref<List<String>>([]);
    final scanning = ref(false);
    final current = ref(hub.pcsc.readerName);
    final state = ref(hub.pcsc.state);
    final keyboard = ref(hub.keyboardEnabled);
    final sounds = ref(hub.soundsEnabled);
    final timeout = ref(hub.sessionTimeoutSeconds);
    final lastCode = ref<String?>(null);

    Future<void> refreshReaders() async {
      scanning.value = true;
      readers.value = await hub.pcsc.listReaders();
      scanning.value = false;
    }

    StreamSubscription<String>? codeSub;
    StreamSubscription<PcscReaderState>? stateSub;
    onMounted(() {
      refreshReaders();
      codeSub = hub.codes.listen((c) {
        lastCode.value = c;
        hub.playCard();
      });
      stateSub = hub.pcsc.stateStream.listen((s) {
        state.value = s;
        current.value = hub.pcsc.readerName;
      });
    });
    onUnmounted(() {
      codeSub?.cancel();
      stateSub?.cancel();
    });

    return (context) => ListView(
          padding: const EdgeInsets.all(28),
          children: [
            const PageHeader(title: 'Inställningar', subtitle: 'Kioskläge, läsare och ljud för den här datorn.'),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const KioskSettingsCard(),
                  const SizedBox(height: 20),
                  SectionCard(
                    title: 'USB-läsare (PC/SC)',
                    icon: Icons.contactless_outlined,
                    trailing: IconButton(
                      tooltip: 'Sök läsare',
                      onPressed: scanning.value ? null : refreshReaders,
                      icon: const Icon(Icons.refresh),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Läsare som ACS ACR1552U läser både bokens RFID-etikett (ISO 15693) och elevens kort. '
                          'Sitter bara en läsare i ansluts den automatiskt.',
                          style: TextStyle(color: AppColors.ink2, height: 1.4),
                        ),
                        const SizedBox(height: 12),
                        if (!PcscReaderService.isSupported)
                          const Text('USB-läsare via PC/SC fungerar i Windows-appen.', style: TextStyle(color: AppColors.error))
                        else if (readers.value.isEmpty)
                          Text(
                            scanning.value ? 'Söker …' : 'Ingen läsare hittades. Sätt i läsaren och tryck på uppdatera.',
                            style: const TextStyle(color: AppColors.ink3),
                          )
                        else
                          RadioGroup<String>(
                            groupValue: current.value,
                            onChanged: (name) => hub.useReader(name),
                            child: Column(
                              children: [
                                for (final name in readers.value)
                                  RadioListTile<String>(
                                    value: name,
                                    title: Text(name),
                                    subtitle: current.value == name && state.value == PcscReaderState.polling
                                        ? const Text('Ansluten — väntar på etiketter', style: TextStyle(color: AppColors.success))
                                        : null,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                              ],
                            ),
                          ),
                        if (current.value != null)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(onPressed: () => hub.useReader(null), child: const Text('Koppla från läsaren')),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SectionCard(
                    title: 'Läsare som skriver som ett tangentbord',
                    icon: Icons.keyboard_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: keyboard.value,
                          onChanged: (v) {
                            keyboard.value = v;
                            hub.setKeyboardEnabled(v);
                          },
                          title: const Text('Ta emot koder från tangentbordsläsare'),
                          subtitle: const Text(
                            'Till exempel skolans Okeeyseda-läsare (USB eller Bluetooth) och streckkodsläsare: de skriver '
                            'numret och trycker Enter. Registrera kort och etiketter med samma läsare som vid utlåningen.',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SectionCard(
                    title: 'Testa läsaren',
                    icon: Icons.sensors,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: lastCode.value == null ? AppColors.surfaceLight : AppColors.successLight,
                        borderRadius: BorderRadius.circular(AppRadius.tile),
                      ),
                      child: Text(
                        lastCode.value == null ? 'Blippa en etikett eller ett kort …' : 'Läst: ${lastCode.value}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: lastCode.value == null ? AppColors.ink3 : AppColors.success,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SectionCard(
                    title: 'Vid disken',
                    icon: Icons.tune,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: sounds.value,
                          onChanged: (v) {
                            sounds.value = v;
                            hub.setSoundsEnabled(v);
                          },
                          title: const Text('Ljud'),
                          subtitle: const Text('Ett pip när en bok lånas eller lämnas, ett annat vid fel.'),
                        ),
                        const SizedBox(height: 8),
                        Text('Låntagaren släpps efter ${timeout.value} sekunder utan aktivitet',
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        Slider(
                          value: timeout.value.toDouble(),
                          min: 15,
                          max: 180,
                          divisions: 11,
                          label: '${timeout.value} s',
                          onChanged: (v) => timeout.value = v.round(),
                          onChangeEnd: (v) => hub.setSessionTimeoutSeconds(v.round()),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SectionCard(
                    title: 'Konto',
                    icon: Icons.person_outline,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(auth.user.value?.name ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text(auth.user.value?.email ?? '', style: const TextStyle(color: AppColors.ink3)),
                              const SizedBox(height: 4),
                              Text(PocketBaseClient.url, style: const TextStyle(color: AppColors.ink3, fontSize: 12.5)),
                            ],
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: auth.signOut,
                          icon: const Icon(Icons.logout),
                          label: const Text('Logga ut'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
  }
}
