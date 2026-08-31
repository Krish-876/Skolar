import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:Skolar/core/theme/app_theme.dart';
import 'auth_mode.dart';
import 'auth_mode_toggle.dart';
import 'preview_text_field.dart';

/// The white sheet + form for the auth screen. Owns its own field
/// controllers so typed input survives the login/signup mode switch even
/// though the mode-specific extra fields are swapped out from under it.
class AuthPreviewSheet extends StatefulWidget {
  final AuthMode mode;
  final bool isLoading;
  final bool isMagicLinkSent;
  final String? sentEmail;
  final ValueChanged<AuthMode> onToggleMode;
  final void Function(String email, String password) onEmailSubmit;
  final VoidCallback onGoogleTap;
  final void Function(String email) onForgotPassword;
  final VoidCallback onReset;

  const AuthPreviewSheet({
    super.key,
    required this.mode,
    this.isLoading = false,
    this.isMagicLinkSent = false,
    this.sentEmail,
    required this.onToggleMode,
    required this.onEmailSubmit,
    required this.onGoogleTap,
    required this.onForgotPassword,
    required this.onReset,
  });

  @override
  State<AuthPreviewSheet> createState() => _AuthPreviewSheetState();
}

class _AuthPreviewSheetState extends State<AuthPreviewSheet> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _rememberMe = false;
  bool _agreeTerms = true;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final isLogin = widget.mode == AuthMode.login;

    String? emailErr;
    String? passErr;
    String? confirmErr;

    // Email validation
    if (email.isEmpty) {
      emailErr = 'Please enter your college email';
    } else if (!email.contains('@') || !email.contains('.')) {
      emailErr = 'Please enter a valid email address';
    }

    // Password validation
    if (password.isEmpty) {
      passErr = 'Please enter your password';
    } else if (!isLogin && password.length < 6) {
      passErr = 'Password must be at least 6 characters';
    }

    // Confirm password and terms on Sign Up
    if (!isLogin) {
      final confirmPass = _confirmPasswordController.text;
      if (confirmPass.isEmpty) {
        confirmErr = 'Please confirm your password';
      } else if (confirmPass != password) {
        confirmErr = 'Passwords do not match';
      }

      if (!_agreeTerms) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please agree to the Terms & Privacy policy'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
    }

    setState(() {
      _emailError = emailErr;
      _passwordError = passErr;
      _confirmPasswordError = confirmErr;
    });

    if (emailErr != null || passErr != null || confirmErr != null) {
      return;
    }

    widget.onEmailSubmit(email, password);
  }

  void _handleForgotPassword() {
    final email = _emailController.text.trim();
    widget.onForgotPassword(email);
  }

  @override
  Widget build(BuildContext context) {
    final isLogin = widget.mode == AuthMode.login;

    return DecoratedBox(
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
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeIn,
              child: widget.isMagicLinkSent
                  ? _buildMagicLinkSentView()
                  : _buildFormView(isLogin),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormView(bool isLogin) {
    return SingleChildScrollView(
      key: const ValueKey('auth-form-view'),
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
          AuthModeToggle(mode: widget.mode, onChanged: widget.onToggleMode),
          const SizedBox(height: AppTheme.lg),
          PreviewTextField(
            controller: _emailController,
            label: 'College Email',
            hint: 'you@campus.bits-pilani.ac.in',
            icon: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
            errorText: _emailError,
          ),
          const SizedBox(height: AppTheme.md),
          PreviewTextField(
            controller: _passwordController,
            label: 'Password',
            hint: '••••••••',
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
            isLoading: widget.isLoading,
            onTap: widget.isLoading ? () {} : _handleSubmit,
          ),
          const SizedBox(height: AppTheme.lg),
          _divider(),
          const SizedBox(height: AppTheme.lg),
          _googleButton(),
          const SizedBox(height: AppTheme.lg),
          _footer(isLogin),
        ],
      ),
    );
  }

  Widget _buildMagicLinkSentView() {
    final email = widget.sentEmail ?? _emailController.text.trim();

    return SingleChildScrollView(
      key: const ValueKey('magic-link-sent-view'),
      padding: const EdgeInsets.fromLTRB(
        AppTheme.lg,
        AppTheme.xl,
        AppTheme.lg,
        AppTheme.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: AppTheme.accentPurple.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.accentPurple.withValues(alpha: 0.4),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accentPurple.withValues(alpha: 0.2),
                  blurRadius: 16,
                ),
              ],
            ),
            child: const Icon(
              Icons.mark_email_read_outlined,
              size: 38,
              color: AppTheme.accentPurple,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Check your email',
            style: GoogleFonts.googleSans(
              color: AppTheme.onSurfaceDark,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: GoogleFonts.googleSans(
                color: AppTheme.sheetTextSecondary,
                fontSize: 14,
                height: 1.45,
              ),
              children: [
                const TextSpan(text: "We've sent a verification link to\n"),
                TextSpan(
                  text: email.isNotEmpty ? email : 'your college email',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.onSurfaceDark,
                  ),
                ),
                const TextSpan(
                  text:
                      '.\nClick the link in your email to confirm and sign in.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _ChunkyButton(
            label: 'Resend Verification Email',
            isLoading: widget.isLoading,
            onTap: widget.isLoading
                ? () {}
                : () => widget.onEmailSubmit(email, _passwordController.text),
          ),
          const SizedBox(height: 14),
          TextButton(
            onPressed: widget.onReset,
            child: Text(
              'Use a different email',
              style: GoogleFonts.googleSans(
                color: AppTheme.accentPurple,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF3EDF7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE4D7F5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 16,
                  color: AppTheme.sheetTextSecondary,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    "Can't find the email? Check your spam/junk folder.",
                    style: GoogleFonts.googleSans(
                      color: AppTheme.sheetTextSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
            onTap: _handleForgotPassword,
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
            hint: '••••••••',
            icon: Icons.lock_outline,
            isPassword: true,
            errorText: _confirmPasswordError,
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
                  onChanged: (v) => setState(() => _agreeTerms = v ?? true),
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
        onPressed: widget.isLoading ? null : widget.onGoogleTap,
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
  final bool isLoading;
  final VoidCallback onTap;

  const _ChunkyButton({
    required this.label,
    this.isLoading = false,
    required this.onTap,
  });

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
        transform: (_pressed && !widget.isLoading)
            ? Matrix4.translationValues(0, 4, 0)
            : Matrix4.identity(),
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: AppTheme.accentPurple,
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          boxShadow: (_pressed || widget.isLoading)
              ? []
              : AppTheme.chunkyButtonShadow,
        ),
        alignment: Alignment.center,
        child: widget.isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppTheme.onPrimary,
                ),
              )
            : Text(
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
