import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Divider theme — thin separator lines between settings menu rows.
///
/// Register in [AppTheme.darkTheme]:
/// ```dart
/// dividerTheme: AppDividerTheme.standard,
/// ```
class AppDividerTheme {
  AppDividerTheme._();

  static DividerThemeData get standard => DividerThemeData(
        color: AppTheme.divider,
        thickness: 0.5,
        space: 0,          // no extra vertical space; add padding in list tiles
        indent: AppTheme.md,
        endIndent: AppTheme.md,
      );

  /// Full-bleed variant — no indent, used inside cards.
  static DividerThemeData get fullBleed => DividerThemeData(
        color: AppTheme.divider,
        thickness: 0.5,
        space: 0,
        indent: 0,
        endIndent: 0,
      );
}