import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compositions/flutter_compositions.dart';

import '../../core/di/injection_keys.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import 'kiosk_store.dart';

/// Inställningar för kioskläget: PIN-kod, start i kioskläge och knappen som
/// låser datorn nu.
class KioskSettingsCard extends CompositionWidget {
  const KioskSettingsCard({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final kiosk = inject(kioskStoreKey);
    final contextRef = useContext();
    final (pinController, pin, _) = useTextEditingController();
    final (confirmController, confirm, _) = useTextEditingController();
    final hasPin = ref(kiosk.hasPin);
    final autoStart = ref(kiosk.autoStart);
    final error = ref<String?>(null);

    void toast(String message) {
      final ctx = contextRef.value;
      if (ctx != null && ctx.mounted) showMessage(ctx, message);
    }

    Future<void> savePin() async {
      if (pin.value.length < 4) {
        error.value = 'Minst fyra siffror.';
        return;
      }
      if (pin.value != confirm.value) {
        error.value = 'Koderna är olika.';
        return;
      }
      await kiosk.setPin(pin.value);
      error.value = null;
      hasPin.value = true;
      pinController.clear();
      confirmController.clear();
      toast('PIN-koden är sparad.');
    }

    Future<void> start() async {
      if (await kiosk.enter()) toast('Kioskläget är på. Lås upp med PIN-koden.');
    }

    return (context) {
      final digits = [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(12)];
      return SectionCard(
        title: 'Kioskläge',
        icon: Icons.lock_outline,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Appen fyller skärmen och går inte att stänga eller lämna: Windows-tangenten, Alt+Tab, Alt+F4 och '
              'Aktivitetshanteraren (Ctrl+Shift+Esc) är avstängda. Eleverna kan bara blippa. Du låser upp med PIN-koden.',
              style: TextStyle(color: AppColors.ink2, height: 1.4),
            ),
            if (!KioskStore.isSupported) ...[
              const SizedBox(height: 12),
              const Text('Kioskläget finns bara i Windows-appen.', style: TextStyle(color: AppColors.error)),
            ],
            const SizedBox(height: 16),
            Text(hasPin.value ? 'BYT PIN-KOD' : 'VÄLJ PIN-KOD', style: sectionLabelStyle(context)),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: pinController,
                    obscureText: true,
                    inputFormatters: digits,
                    decoration: InputDecoration(labelText: 'PIN-kod', errorText: error.value, isDense: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: confirmController,
                    obscureText: true,
                    inputFormatters: digits,
                    decoration: const InputDecoration(labelText: 'Samma kod igen', isDense: true),
                    onSubmitted: (_) => savePin(),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(onPressed: pin.value.isEmpty ? null : savePin, child: const Text('Spara')),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: autoStart.value,
              onChanged: hasPin.value
                  ? (v) {
                      autoStart.value = v;
                      kiosk.setAutoStart(v);
                    }
                  : null,
              title: const Text('Starta i kioskläge'),
              subtitle: const Text('Appen låser sig själv när den startar och när någon loggat in.'),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: hasPin.value && KioskStore.isSupported ? start : null,
                icon: const Icon(Icons.lock),
                label: const Text('Lås datorn nu'),
              ),
            ),
            if (!hasPin.value)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Välj en PIN-kod först.', style: TextStyle(color: AppColors.ink3)),
              ),
          ],
        ),
      );
    };
  }
}
