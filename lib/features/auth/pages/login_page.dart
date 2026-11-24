import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';

import '../../../core/di/injection_keys.dart';
import '../../../core/theme/app_theme.dart';

/// Inloggning — som i webben: Microsoft eller Google, inga lösenord.
class LoginPage extends CompositionWidget {
  const LoginPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final auth = inject(authStoreKey);
    final error = ref<String?>(null);

    Future<void> signIn(String provider) async {
      error.value = null;
      error.value = await auth.signIn(provider);
    }

    return (context) {
      final busy = auth.signingIn.value;
      return Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(32, 36, 32, 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(16)),
                          child: const Icon(Icons.local_library_outlined, color: Colors.white, size: 32),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text('Skolpunkten Bibliotek', textAlign: TextAlign.center, style: pageTitleStyle(context).copyWith(fontSize: 26)),
                      const SizedBox(height: 8),
                      const Text(
                        'Logga in med ett lärar- eller adminkonto. Sedan lånar elever och lärare genom att blippa böcker och lånekort.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.ink2, fontSize: 15, height: 1.4),
                      ),
                      const SizedBox(height: 28),
                      if (error.value != null) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.errorLight,
                            borderRadius: BorderRadius.circular(AppRadius.tile),
                          ),
                          child: Text(error.value!, style: const TextStyle(color: AppColors.error)),
                        ),
                        const SizedBox(height: 16),
                      ],
                      _ProviderButton(
                        label: 'Logga in med Microsoft',
                        logo: const _MicrosoftLogo(),
                        loading: busy == 'microsoft',
                        disabled: busy != null,
                        onPressed: () => signIn('microsoft'),
                      ),
                      const SizedBox(height: 12),
                      _ProviderButton(
                        label: 'Logga in med Google',
                        logo: const Text('G',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF4285F4))),
                        loading: busy == 'google',
                        disabled: busy != null,
                        onPressed: () => signIn('google'),
                      ),
                      if (busy != null) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Slutför inloggningen i webbläsaren och kom sedan tillbaka hit.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.ink3),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    };
  }
}

class _ProviderButton extends StatelessWidget {
  const _ProviderButton({
    required this.label,
    required this.logo,
    required this.loading,
    required this.disabled,
    required this.onPressed,
  });

  final String label;
  final Widget logo;
  final bool loading;
  final bool disabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: disabled ? null : onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            else
              SizedBox(width: 20, height: 20, child: Center(child: logo)),
            const SizedBox(width: 12),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _MicrosoftLogo extends StatelessWidget {
  const _MicrosoftLogo();

  @override
  Widget build(BuildContext context) {
    Widget square(int color) => Container(width: 8, height: 8, color: Color(color));
    return SizedBox(
      width: 18,
      height: 18,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [square(0xFFF25022), square(0xFF7FBA00)]),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [square(0xFF00A4EF), square(0xFFFFB900)]),
        ],
      ),
    );
  }
}
