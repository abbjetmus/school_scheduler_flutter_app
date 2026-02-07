import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/injection_keys.dart';

class ForgotPasswordPage extends CompositionWidget {
  const ForgotPasswordPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final authStore = inject(authStoreKey);
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final message = ref<String?>(null);
    final isError = ref<bool>(false);

    Future<void> handleReset() async {
      if (!formKey.currentState!.validate()) return;
      final success =
          await authStore.forgotPassword(emailController.text.trim());
      if (success) {
        message.value = 'Återställningslänk skickad till din e-post.';
        isError.value = false;
      } else {
        message.value = 'Kunde inte skicka återställningslänk.';
        isError.value = true;
      }
    }

    return (context) {
      return Scaffold(
        appBar: AppBar(title: const Text('Glömt lösenord')),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: formKey,
                child: Column(
                  children: [
                    const Icon(Icons.lock_reset, size: 64, color: Colors.blue),
                    const SizedBox(height: 16),
                    const Text(
                      'Ange din e-postadress för att återställa lösenordet.',
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
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: 'E-post',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Ange e-post' : null,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: handleReset,
                        child: const Text('Skicka återställningslänk'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => context.pop(),
                      child: const Text('Tillbaka till inloggning'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    };
  }
}
