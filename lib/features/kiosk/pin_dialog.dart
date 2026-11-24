import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compositions/flutter_compositions.dart';

import '../../core/theme/app_theme.dart';
import 'kiosk_store.dart';

/// Lås upp kioskläget — eller avsluta appen — med PIN-koden.
Future<void> showUnlockDialog(BuildContext context, KioskStore kiosk, {bool closing = false}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _UnlockDialog(kiosk: kiosk, closing: closing),
  );
}

class _UnlockDialog extends CompositionWidget {
  const _UnlockDialog({required this.kiosk, required this.closing});
  final KioskStore kiosk;
  final bool closing;

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final (controller, _, _) = useTextEditingController();
    final error = ref<String?>(null);
    final contextRef = useContext();

    Future<void> run(Future<bool> Function(String pin) action) async {
      final ok = await action(controller.text);
      final ctx = contextRef.value;
      if (ctx == null || !ctx.mounted) return;
      if (ok) {
        Navigator.of(ctx).pop();
      } else {
        error.value = 'Fel PIN-kod.';
        controller.clear();
      }
    }

    return (context) {
      final p = props.value;
      final primary = p.closing ? p.kiosk.quit : p.kiosk.unlock;
      return AlertDialog(
        title: Text(p.closing ? 'Avsluta biblioteket?' : 'Lås upp'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Skriv PIN-koden för bibliotekets dator.', style: TextStyle(color: AppColors.ink2)),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                obscureText: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(12)],
                decoration: InputDecoration(
                  labelText: 'PIN-kod',
                  errorText: error.value,
                  prefixIcon: const Icon(Icons.lock_outline),
                ),
                onSubmitted: (_) => run(primary),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Avbryt')),
          if (!p.closing) TextButton(onPressed: () => run(p.kiosk.quit), child: const Text('Avsluta appen')),
          FilledButton(onPressed: () => run(primary), child: Text(p.closing ? 'Avsluta' : 'Lås upp')),
        ],
      );
    };
  }
}
