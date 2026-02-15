import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/injection_keys.dart';

class LoginPage extends CompositionWidget {
  const LoginPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final authStore = inject(authStoreKey);
    final errorMessage = ref<String?>(null);
    final contextRef = useContext();

    Future<void> handleMicrosoftLogin() async {
      errorMessage.value = null;
      try {
        await authStore.signInWithMicrosoft();
        final ctx = contextRef.value;
        if (ctx != null && ctx.mounted) {
          ctx.go('/dashboard');
        }
      } catch (e) {
        errorMessage.value = 'Microsoft-inloggning misslyckades: $e';
      }
    }

    return (context) {
      return Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Background image
            Image.asset(
              'assets/login_bg.jpg',
              fit: BoxFit.cover,
            ),
            // Dark overlay
            Container(
              color: Colors.black.withValues(alpha: 0.5),
            ),
            // Content
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 48),
                        child: Text(
                          'SKOLPUNKTEN',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Appen som samlar funktionalitet\nfor skola, pa en punkt!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w300,
                          color: Colors.white,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 48),

                      // Error message
                      if (errorMessage.value != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          constraints: const BoxConstraints(maxWidth: 500),
                          decoration: BoxDecoration(
                            color: Colors.red.shade900.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error, color: Colors.white),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  errorMessage.value!,
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Microsoft login button
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 500),
                        child: SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: authStore.loading.value
                                ? null
                                : handleMicrosoftLogin,
                            icon: authStore.loading.value
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.black54,
                                    ),
                                  )
                                : const Icon(Icons.login, color: Colors.black87),
                            label: const Text(
                              'Logga in med Microsoft',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black87,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 2,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 48),

                      // Feature cards
                      _buildFeatureCards(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    };
  }

  static Widget _buildFeatureCards() {
    const features = [
      (
        title: 'Bygga formulor och gora undersokningar',
        icon: Icons.description,
      ),
      (
        title: 'SMS och e-post paminnelser infor t.ex. oppet hus',
        icon: Icons.notifications,
      ),
      (
        title: 'Emoji-undersokningar',
        icon: Icons.mood,
      ),
      (
        title: 'Kom at undersokningar via QR-koder',
        icon: Icons.qr_code,
      ),
    ];

    return IntrinsicHeight(
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.center,
        children: features.map((feature) {
          return SizedBox(
            width: 200,
            height: 140,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(feature.icon, size: 48, color: Colors.blue.shade300),
                  const SizedBox(height: 8),
                  Text(
                    feature.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
