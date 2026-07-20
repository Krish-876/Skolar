import 'package:Skolar/core/routing/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:Skolar/features/auth/presentation/providers/auth_provider.dart';
import 'package:Skolar/core/theme/app_theme.dart';

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
          router.go(AppRoutes.onboardingProfile);
        } else {
          router.go('/');
        }
      });
    });

    final isLoading = authState.status == AuthStatus.loading;
    final isSent = authState.status == AuthStatus.magicLinkSent;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Mascot image
                  Center(
                    child: Hero(
                      tag: 'mascot_hero',
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.accentPurple.withValues(
                                alpha: 0.3,
                              ),
                              blurRadius: 40,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/mascot.jpeg',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Title
                  Center(
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        children: [
                          TextSpan(text: 'Welcome to '),
                          TextSpan(
                            text: 'Skolar',
                            style: TextStyle(color: AppTheme.accentPurple),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Subtitle
                  const Text(
                    'Your AI-powered study companion for\nBITS Hyderabad.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.onBackground2,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 40),

                  if (!isSent) ...[
                    // INSTITUTIONAL EMAIL label
                    const Text(
                      'INSTITUTIONAL EMAIL',
                      style: TextStyle(
                        color: AppTheme.onBackground2,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Email Field
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      onSubmitted: (_) => _onSubmit(),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppTheme.surfaceLight.withValues(alpha: 0.5),
                        hintText: 'name@campusname.bits-pilani.ac.in',
                        hintStyle: TextStyle(
                          color: AppTheme.onBackground2.withValues(alpha: 0.5),
                        ),
                        prefixIcon: const Icon(
                          Icons.mail_outline,
                          color: AppTheme.onBackground2,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Send Magic Link Button
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _onSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentPurple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Send Magic Link',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_forward, size: 20),
                                ],
                              ),
                      ),
                    ),
                  ] else ...[
                    const Icon(
                      Icons.mark_email_read_outlined,
                      size: 64,
                      color: AppTheme.accentPurple,
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () =>
                          ref.read(authNotifierProvider.notifier).reset(),
                      child: const Text(
                        'Use a different email',
                        style: TextStyle(color: AppTheme.accentPurple),
                      ),
                    ),
                  ],

                  const SizedBox(height: 40),

                  // Divider
                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: AppTheme.onBackground2.withValues(alpha: 0.2),
                          thickness: 1,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'OR CONTINUE WITH',
                          style: TextStyle(
                            color: AppTheme.onBackground2.withValues(
                              alpha: 0.5,
                            ),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: AppTheme.onBackground2.withValues(alpha: 0.2),
                          thickness: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Google Workspace Button
                  SizedBox(
                    height: 56,
                    child: OutlinedButton(
                      onPressed: () {
                        // TODO: Implement Google Workspace auth logic
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: AppTheme.onBackground2.withValues(alpha: 0.2),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.g_mobiledata,
                            size: 32,
                            color: Colors.white,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Google Workspace',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Info Box
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppTheme.onBackground2,
                        size: 14,
                      ),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Use your bits-pilani.ac.in email',
                          style: TextStyle(
                            color: AppTheme.onBackground2,
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Footer
                  Center(
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: const TextSpan(
                        style: TextStyle(
                          color: AppTheme.onBackground2,
                          fontSize: 12,
                          height: 1.5,
                        ),
                        children: [
                          TextSpan(
                            text: 'By continuing, you agree to Skolar\'s ',
                          ),
                          TextSpan(
                            text: 'Terms of Service',
                            style: TextStyle(
                              color: Colors.white,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          TextSpan(text: '\nand '),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: TextStyle(
                              color: Colors.white,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          TextSpan(text: '.'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
