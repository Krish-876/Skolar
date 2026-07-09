import 'package:Skolar/core/routing/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:Skolar/features/auth/presentation/providers/auth_provider.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _emailController = TextEditingController();
  bool _justLoggedIn = false;

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
    _justLoggedIn = true;
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
      next.whenData((session) async {
        if (session == null || !mounted || !_justLoggedIn) return;
        _justLoggedIn = false;
        final router = GoRouter.of(context); // capture before async gap
        final isNew = await _isNewUser(session.user.id);
        if (!mounted) return;
        if (isNew) {
          router.go(AppRoutes.onboarding);
        } else {
          router.go('/');
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
                isSent
                    ? 'Check your college inbox'
                    : 'Enter your college email',
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

  // Returns true if user row doesn't exist or has no full_name yet
  Future<bool> _isNewUser(String userId) async {
    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('full_name')
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return true;
      final name = response['full_name'] as String?;
      return name == null || name.trim().isEmpty;
    } catch (_) {
      return true;
    }
  }
}
