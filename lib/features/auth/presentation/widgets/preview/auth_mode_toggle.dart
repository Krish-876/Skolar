import 'package:flutter/material.dart';
import 'package:Skolar/core/theme/app_theme.dart';
import 'auth_mode.dart';

/// Segmented Log In / Sign Up pill. The active half is filled with
/// [AppTheme.accentPurple] and slides under the active label.
class AuthModeToggle extends StatelessWidget {
  final AuthMode mode;
  final ValueChanged<AuthMode> onChanged;

  const AuthModeToggle({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isLogin = mode == AuthMode.login;

    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.sheetFieldFill,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: isLogin ? Alignment.centerLeft : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppTheme.accentPurple,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _ToggleLabel(
                  label: 'Log In',
                  active: isLogin,
                  onTap: () => onChanged(AuthMode.login),
                ),
              ),
              Expanded(
                child: _ToggleLabel(
                  label: 'Sign Up',
                  active: !isLogin,
                  onTap: () => onChanged(AuthMode.signup),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ToggleLabel extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ToggleLabel({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'GoogleSans',
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: active ? AppTheme.onPrimary : AppTheme.sheetTextSecondary,
          ),
        ),
      ),
    );
  }
}
