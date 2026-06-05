import 'package:Skolar/core/routing/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Skolar/features/auth/presentation/providers/auth_provider.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _onSubmit() {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showSnackbar('Please enter your college email');
      return;
    }
    ref.read(authNotifierProvider.notifier).sendMagicLink(email);
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    ref.listen(authNotifierProvider, (_, next) {
      if (next.status == AuthStatus.error && next.errorMessage != null) {
        _showSnackbar(next.errorMessage!);
        ref.read(authNotifierProvider.notifier).reset();
      }
      if (next.status == AuthStatus.magicLinkSent) {
        _showSnackbar('Magic link sent! Check your college email.');
      }
    });

    ref.listen(authSessionProvider, (_, next) {
      next.whenData((session) {
        if (session != null) {
          Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
        }
      });
    });

    final isLoading = authState.status == AuthStatus.loading;
    final isSent = authState.status == AuthStatus.magicLinkSent;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Skolar', style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 8),
              Text(
                isSent ? 'Check your college inbox' : 'Enter your college email',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              if (!isSent) ...[
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  onSubmitted: (_) => _onSubmit(),
                  decoration: const InputDecoration(
                    labelText: 'College Email',
                    hintText: 'f20240175@hyderabad.bits-pilani.ac.in',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _onSubmit,
                    child: isLoading
                        ? const CircularProgressIndicator(strokeWidth: 2)
                        : const Text('Send Magic Link'),
                  ),
                ),
              ] else ...[
                const Icon(Icons.mark_email_read_outlined, size: 64),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () =>
                      ref.read(authNotifierProvider.notifier).reset(),
                  child: const Text('Use a different email'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}