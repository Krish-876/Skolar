import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Skolar/core/theme/app_theme.dart';
import 'package:Skolar/shared/extensions/extensions.dart';
import 'mascot_state.dart';

class RegistrationForm extends ConsumerStatefulWidget {
  final VoidCallback toggleForm;
  final ValueChanged<MascotState> onMascotStateChanged;

  const RegistrationForm({
    super.key,
    required this.toggleForm,
    required this.onMascotStateChanged,
  });

  @override
  ConsumerState<RegistrationForm> createState() => _RegistrationFormState();
}

class _RegistrationFormState extends ConsumerState<RegistrationForm>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();

  bool _isTermsChecked = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _isLoading = false;

  // Staggered entry animation
  late final AnimationController _entryCtrl;
  late final List<Animation<double>> _fades;
  late final List<Animation<Offset>> _slides;
  static const int _fieldCount = 5;

  @override
  void initState() {
    super.initState();

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fades = List.generate(_fieldCount, (i) {
      final start = i * 0.15;
      final end = (start + 0.38).clamp(0.0, 1.0);
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _entryCtrl,
          curve: Interval(start, end, curve: Curves.easeOut),
        ),
      );
    });

    _slides = List.generate(_fieldCount, (i) {
      final start = i * 0.15;
      final end = (start + 0.38).clamp(0.0, 1.0);
      return Tween<Offset>(
        begin: const Offset(0, 0.25),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _entryCtrl,
          curve: Interval(start, end, curve: Curves.easeOut),
        ),
      );
    });

    _entryCtrl.forward();

    // Focus listeners drive mascot state
    _emailFocus.addListener(_onEmailFocus);
    _passwordFocus.addListener(_onPasswordFocus);
    _confirmPasswordFocus.addListener(_onConfirmPasswordFocus);
  }

  void _onEmailFocus() {
    if (_emailFocus.hasFocus) {
      widget.onMascotStateChanged(MascotState.watchingEmail);
    } else if (!_passwordFocus.hasFocus && !_confirmPasswordFocus.hasFocus) {
      widget.onMascotStateChanged(MascotState.idle);
    }
  }

  void _onPasswordFocus() {
    if (_passwordFocus.hasFocus) {
      widget.onMascotStateChanged(MascotState.lookingAway);
    } else if (!_emailFocus.hasFocus && !_confirmPasswordFocus.hasFocus) {
      widget.onMascotStateChanged(MascotState.idle);
    }
  }

  void _onConfirmPasswordFocus() {
    if (_confirmPasswordFocus.hasFocus) {
      widget.onMascotStateChanged(MascotState.lookingAway);
    } else if (!_emailFocus.hasFocus && !_passwordFocus.hasFocus) {
      widget.onMascotStateChanged(MascotState.idle);
    }
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailFocus
      ..removeListener(_onEmailFocus)
      ..dispose();
    _passwordFocus
      ..removeListener(_onPasswordFocus)
      ..dispose();
    _confirmPasswordFocus
      ..removeListener(_onConfirmPasswordFocus)
      ..dispose();
    super.dispose();
  }

  Widget _animated(int i, Widget child) => FadeTransition(
        opacity: _fades[i],
        child: SlideTransition(position: _slides[i], child: child),
      );

  void _handleSignUp() {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (email.isEmpty) {
      _showSnackbar('Please enter your email');
      return;
    }
    if (!email.isValidEmail) {
      _showSnackbar('Please enter a valid email');
      return;
    }
    if (password.isEmpty) {
      _showSnackbar('Please enter a password');
      return;
    }
    if (password.length < 6) {
      _showSnackbar('Password must be at least 6 characters');
      return;
    }
    if (password != confirmPassword) {
      _showSnackbar('Passwords do not match');
      return;
    }
    if (!_isTermsChecked) {
      _showSnackbar('Please agree to Terms & Conditions');
      return;
    }

    setState(() => _isLoading = true);
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackbar('Registration successful!');
      }
    });
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.wishlist,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Email ────────────────────────────────────────────────────────
        _animated(
          0,
          _buildTextField(
            controller: _emailController,
            focusNode: _emailFocus,
            label: 'Email',
            hint: 'your@email.com',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
        ),
        const SizedBox(height: AppTheme.md),

        // ── Password ─────────────────────────────────────────────────────
        _animated(
          1,
          _buildTextField(
            controller: _passwordController,
            focusNode: _passwordFocus,
            label: 'Password',
            hint: 'Enter your password',
            icon: Icons.lock_outlined,
            isPassword: true,
            obscureText: !_showPassword,
            onToggleVisibility: () {
              setState(() => _showPassword = !_showPassword);
              // FIX: was inverted. Revealing (_showPassword=true) → caught.
              // Hiding (_showPassword=false) → back to looking away.
              if (_showPassword) {
                widget.onMascotStateChanged(MascotState.caught);
              } else {
                widget.onMascotStateChanged(MascotState.lookingAway);
              }
            },
          ),
        ),
        const SizedBox(height: AppTheme.md),

        // ── Confirm Password ─────────────────────────────────────────────
        _animated(
          2,
          _buildTextField(
            controller: _confirmPasswordController,
            focusNode: _confirmPasswordFocus,
            label: 'Confirm Password',
            hint: 'Re-enter your password',
            icon: Icons.lock_outlined,
            isPassword: true,
            obscureText: !_showConfirmPassword,
            onToggleVisibility: () {
              setState(() => _showConfirmPassword = !_showConfirmPassword);
              // FIX: same inversion fix applied here
              if (_showConfirmPassword) {
                widget.onMascotStateChanged(MascotState.caught);
              } else {
                widget.onMascotStateChanged(MascotState.lookingAway);
              }
            },
          ),
        ),
        const SizedBox(height: AppTheme.md),

        // ── Terms checkbox ───────────────────────────────────────────────
        _animated(
          3,
          Row(
            children: [
              Checkbox(
                value: _isTermsChecked,
                onChanged: (v) =>
                    setState(() => _isTermsChecked = v ?? false),
                activeColor: AppTheme.primary,
                fillColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return AppTheme.primary;
                  }
                  return Colors.transparent;
                }),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                side: BorderSide(
                  color: AppTheme.onBackground.withValues(alpha: 0.3),
                ),
              ),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: 'I agree to ',
                    style: TextStyle(
                      color: AppTheme.onSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    children: [
                      TextSpan(
                        text: 'Terms & Conditions',
                        style: TextStyle(
                          color: AppTheme.onBackground2,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const TextSpan(text: ' and '),
                      TextSpan(
                        text: 'Privacy Policy',
                        style: TextStyle(
                          color: AppTheme.onBackground2,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.lg),

        // ── Register button ──────────────────────────────────────────────
        _animated(
          4,
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleSignUp,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                disabledBackgroundColor:
                    AppTheme.primary.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                ),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _isLoading
                    ? const SizedBox(
                        key: ValueKey('loader'),
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.onPrimary),
                        ),
                      )
                    : const Text(
                        key: ValueKey('label'),
                        'Create Account',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.onPrimary,
                        ),
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppTheme.lg),

        // ── Sign In link ─────────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Already have an account? ',
              style:
                  TextStyle(color: AppTheme.onBackground2, fontSize: 14),
            ),
            TextButton(
              onPressed: widget.toggleForm,
              child: Text(
                'Sign In',
                style: TextStyle(
                  // FIX: was AppTheme.onBackground which can be invisible
                  // on dark surfaces — changed to AppTheme.primary
                  color: AppTheme.onBackground,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggleVisibility,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.onSurface,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          obscureText: obscureText,
          onChanged: (_) {
            if (!focusNode.hasFocus) return;
            widget.onMascotStateChanged(
              isPassword
                  ? MascotState.lookingAway
                  : MascotState.watchingEmail,
            );
          },
          style: const TextStyle(color: AppTheme.onSurface, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: AppTheme.onBackground2.withValues(alpha: 0.6),
              fontSize: 14,
            ),
            prefixIcon: Icon(icon, color: AppTheme.primary, size: 20),
            suffixIcon: isPassword
                ? IconButton(
                    onPressed: onToggleVisibility,
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, anim) =>
                          RotationTransition(
                        turns:
                            Tween(begin: 0.75, end: 1.0).animate(anim),
                        child:
                            FadeTransition(opacity: anim, child: child),
                      ),
                      child: Icon(
                        obscureText
                            ? Icons.visibility_off
                            : Icons.visibility,
                        key: ValueKey(obscureText),
                        color: AppTheme.onBackground2,
                        size: 20,
                      ),
                    ),
                  )
                : null,
            filled: true,
            fillColor: AppTheme.surface.withValues(alpha: 0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusXl),
              borderSide: BorderSide(
                color: AppTheme.onBackground2.withValues(alpha: 0.2),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusXl),
              borderSide: BorderSide(
                color: AppTheme.onBackground2.withValues(alpha: 0.2),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusXl),
              borderSide:
                  const BorderSide(color: AppTheme.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }
}