import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/injection_keys.dart';

class EmailVerificationPage extends CompositionWidget {
  final String? token;

  const EmailVerificationPage({super.key, this.token});

  @override
  Widget Function(BuildContext) setup() {
    final authStore = inject(authStoreKey);
    final tokenController = TextEditingController(text: token ?? '');
    final message = ref<String?>(null);
    final isError = ref<bool>(false);
    final isVerified = ref<bool>(false);

    Future<void> handleVerify() async {
      if (tokenController.text.trim().isEmpty) {
        message.value = 'Ange verifieringstoken';
        isError.value = true;
        return;
      }
      final success =
          await authStore.confirmVerification(tokenController.text.trim());
      if (success) {
        message.value = 'E-post verifierad! Du kan nu logga in.';
        isError.value = false;
        isVerified.value = true;
      } else {
        message.value = 'Verifieringen misslyckades. Kontrollera token.';
        isError.value = true;
      }
    }

    return (context) {
      return Scaffold(
        appBar: AppBar(title: const Text('E-postverifiering')),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                children: [
                  const Icon(Icons.mark_email_read, size: 64, color: Colors.blue),
                  const SizedBox(height: 16),
                  const Text(
                    'Ange verifieringstoken från din e-post.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (message.value != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: isError.value
                            ? Colors.red.shade50
                            : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        message.value!,
                        style: TextStyle(
                          color: isError.value ? Colors.red : Colors.green,
                        ),
                      ),
                    ),
                  TextFormField(
                    controller: tokenController,
                    decoration: const InputDecoration(
                      labelText: 'Verifieringstoken',
                      prefixIcon: Icon(Icons.vpn_key),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (!isVerified.value)
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: handleVerify,
                        child: const Text('Verifiera'),
                      ),
                    ),
                  if (isVerified.value)
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: () => context.go('/login'),
                        child: const Text('Gå till inloggning'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    };
  }
}
