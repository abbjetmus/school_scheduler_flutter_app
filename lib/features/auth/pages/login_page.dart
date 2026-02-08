import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/injection_keys.dart';

class LoginPage extends CompositionWidget {
  const LoginPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final authStore = inject(authStoreKey);
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final errorMessage = ref<String?>(null);
    final contextRef = useContext();

    // Microsoft OAuth2 login handler
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

    // Email/password login (commented dout for now)
    Future<void> handleLogin() async {
      if (!formKey.currentState!.validate()) return;
      errorMessage.value = null;
      try {
        await authStore.signIn(emailController.text.trim(), passwordController.text);
        final ctx = contextRef.value;
        if (ctx != null && ctx.mounted) {
          ctx.go('/dashboard');
        }
      } catch (e) {
        errorMessage.value = 'Felaktiga inloggningsuppgifter';
      }
    }

    return (context) {
      return Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.school, size: 80, color: Colors.blue),
                    const SizedBox(height: 16),
                    const Text('School Scheduler', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 32),
                    if (errorMessage.value != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          children: [
                            const Icon(Icons.error, color: Colors.red),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(errorMessage.value!, style: const TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      ),

                    // Microsoft OAuth2 Login Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton.icon(
                        onPressed: authStore.loading.value ? null : handleMicrosoftLogin,
                        icon: authStore.loading.value
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.login, size: 24),
                        label: const Text('Logga in med Microsoft', style: TextStyle(fontSize: 16)),
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.blue, width: 2)),
                      ),
                    ),

                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 8),

                    // Email/Password login (commented out for now)
                    /*
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
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Lösenord',
                        prefixIcon: Icon(Icons.lock),
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Ange lösenord' : null,
                      onFieldSubmitted: (_) => handleLogin(),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed:
                            authStore.loading.value ? null : handleLogin,
                        child: authStore.loading.value
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Logga in'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => context.push('/forgot-password'),
                      child: const Text('Glömt lösenord?'),
                    ),
                    TextButton(
                      onPressed: () => context.push('/register'),
                      child: const Text('Skapa konto'),
                    ),
                    */
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
