import 'package:flutter/material.dart';
import 'package:Skolar/core/theme/app_theme.dart';
import 'auth_mode.dart';
import 'auth_mode_toggle.dart';
import 'preview_text_field.dart';

/// The white sheet + form for the auth preview screen. Owns its own field
/// controllers so typed input survives the login/signup mode switch even
/// though the mode-specific extra fields are swapped out from under it.
class AuthPreviewSheet extends StatefulWidget {
  final AuthMode mode;
  final ValueChanged<AuthMode> onToggleMode;
  final VoidCallback onEmailSubmit;
  final VoidCallback onGoogleTap;
  final VoidCallback onForgotPassword;

  const AuthPreviewSheet({
    super.key,
    required this.mode,
    required this.onToggleMode,
    required this.onEmailSubmit,
    required this.onGoogleTap,
    required this.onForgotPassword,
  });

  @override
  State<AuthPreviewSheet> createState() => _AuthPreviewSheetState();
}

class _AuthPreviewSheetState extends State<AuthPreviewSheet> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _rememberMe = false;
  bool _agreeTerms = false;
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    // Visual-only validation — no real rules, just error-state styling.
    setState(() {
      _emailError = _emailController.text.trim().isEmpty ? 'Required' : null;
      _passwordError = _passwordController.text.trim().isEmpty
          ? 'Required'
          : null;
    });
    widget.onEmailSubmit();
  }

  @override
  Widget build(BuildContext context) {
    final isLogin = widget.mode == AuthMode.login;

    return DecoratedBox(
      // Sits on the OUTSIDE of the ClipRRect below so the shadow — which
      // extends past the sheet's own bounds — isn't clipped away with it.
      // Static rather than growing with the rise: cheap, and the spec
      // allows it ("static shadow is fine if animating it costs frames").
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXxxl),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.dropShadow,
            blurRadius: 24,
            spreadRadius: -4,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: ClipRRect(
        clipBehavior: Clip.hardEdge,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXxxl),
        ),
        child: DecoratedBox(
          decoration: const BoxDecoration(color: AppTheme.sheetBackground),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              // SingleChildScrollView already sizes to its child's natural
              // height, clamped by whatever constraint its ancestor gives it.
              // The outer ConstrainedBox in auth_preview_page.dart supplies
              // that cap — beyond it this scrolls internally instead of
              // overflowing.
              padding: const EdgeInsets.fromLTRB(
                AppTheme.lg,
                AppTheme.lg,
                AppTheme.lg,
                AppTheme.md,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AuthModeToggle(
                    mode: widget.mode,
                    onChanged: widget.onToggleMode,
                  ),
                  const SizedBox(height: AppTheme.lg),
                  PreviewTextField(
                    controller: _emailController,
                    label: 'Email',
                    hint: 'you@bits-pilani.ac.in',
                    icon: Icons.mail_outline,
                    keyboardType: TextInputType.emailAddress,
                    errorText: _emailError,
                  ),
                  const SizedBox(height: AppTheme.md),
                  PreviewTextField(
                    controller: _passwordController,
                    label: 'Password',
                    hint: 'Enter your password',
                    icon: Icons.lock_outline,
                    isPassword: true,
                    errorText: _passwordError,
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    alignment: Alignment.topCenter,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      // Default layoutBuilder centres both children, which lets
                      // the taller outgoing child overflow upward past the
                      // sheet's top edge mid-transition. Stack top-aligned
                      // instead so it only ever grows downward.
                      layoutBuilder: (currentChild, previousChildren) => Stack(
                        alignment: Alignment.topCenter,
                        children: [...previousChildren, ?currentChild],
                      ),
                      child: isLogin ? _loginExtras() : _signupExtras(),
                    ),
                  ),
                  const SizedBox(height: AppTheme.md),
                  _ChunkyButton(
                    label: isLogin ? 'Log In' : 'Sign Up',
                    onTap: _handleSubmit,
                  ),
                  const SizedBox(height: AppTheme.lg),
                  _divider(),
                  const SizedBox(height: AppTheme.lg),
                  _googleButton(),
                  const SizedBox(height: AppTheme.lg),
                  _footer(isLogin),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _loginExtras() {
    return Padding(
      key: const ValueKey('login-extras'),
      padding: const EdgeInsets.only(top: AppTheme.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: _rememberMe,
                  onChanged: (v) => setState(() => _rememberMe = v ?? false),
                  activeColor: AppTheme.accentPurple,
                  side: const BorderSide(color: AppTheme.sheetTextSecondary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.sm),
              const Text(
                'Remember me',
                style: TextStyle(
                  fontFamily: 'GoogleSans',
                  color: AppTheme.sheetTextSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: widget.onForgotPassword,
            child: const Text(
              'Forgot password?',
              style: TextStyle(
                fontFamily: 'GoogleSans',
                color: AppTheme.accentPurple,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _signupExtras() {
    return Padding(
      key: const ValueKey('signup-extras'),
      padding: const EdgeInsets.only(top: AppTheme.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PreviewTextField(
            controller: _confirmPasswordController,
            label: 'Confirm Password',
            hint: 'Re-enter your password',
            icon: Icons.lock_outline,
            isPassword: true,
          ),
          const SizedBox(height: AppTheme.sm),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: _agreeTerms,
                  onChanged: (v) => setState(() => _agreeTerms = v ?? false),
                  activeColor: AppTheme.accentPurple,
                  side: const BorderSide(color: AppTheme.sheetTextSecondary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.sm),
              const Expanded(
                child: Text(
                  'Agree to Terms & Privacy',
                  style: TextStyle(
                    fontFamily: 'GoogleSans',
                    color: AppTheme.sheetTextSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return const Row(
      children: [
        Expanded(child: Divider(color: AppTheme.sheetBorder, thickness: 1)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppTheme.smd),
          child: Text(
            'or continue with',
            style: TextStyle(
              fontFamily: 'GoogleSans',
              color: AppTheme.sheetTextSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(child: Divider(color: AppTheme.sheetBorder, thickness: 1)),
      ],
    );
  }

  Widget _googleButton() {
    return SizedBox(
      height: 56,
      child: OutlinedButton(
        onPressed: widget.onGoogleTap,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppTheme.sheetBorder, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.g_mobiledata, size: 28, color: AppTheme.onSurfaceDark),
            SizedBox(width: AppTheme.sm),
            Text(
              'Continue with Google',
              style: TextStyle(
                fontFamily: 'GoogleSans',
                color: AppTheme.onSurfaceDark,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _footer(bool isLogin) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          isLogin ? "Don't have an account? " : 'Already have an account? ',
          style: const TextStyle(
            fontFamily: 'GoogleSans',
            color: AppTheme.sheetTextSecondary,
            fontSize: 13,
          ),
        ),
        GestureDetector(
          onTap: () =>
              widget.onToggleMode(isLogin ? AuthMode.signup : AuthMode.login),
          child: Text(
            isLogin ? 'Sign Up' : 'Log in',
            style: const TextStyle(
              fontFamily: 'GoogleSans',
              color: AppTheme.accentPurple,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

/// Matches `_ChunkyButton` in onboarding_welcome_page.dart: 4px translate
/// down on press, shadow removed while pressed.
class _ChunkyButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _ChunkyButton({required this.label, required this.onTap});

  @override
  State<_ChunkyButton> createState() => _ChunkyButtonState();
}

class _ChunkyButtonState extends State<_ChunkyButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        transform: _pressed
            ? Matrix4.translationValues(0, 4, 0)
            : Matrix4.identity(),
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: AppTheme.accentPurple,
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          boxShadow: _pressed ? [] : AppTheme.chunkyButtonShadow,
        ),
        alignment: Alignment.center,
        child: Text(
          widget.label,
          style: const TextStyle(
            fontFamily: 'GoogleSans',
            color: AppTheme.onPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
