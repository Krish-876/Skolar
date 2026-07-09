import 'package:flutter/material.dart';
import 'app_theme.dart';

/// SnackBar theme + convenience show helpers.
///
/// Register in [AppTheme.darkTheme]:
/// ```dart
/// snackBarTheme: AppSnackbarTheme.standard,
/// ```
///
/// Show helpers:
/// ```dart
/// AppSnackbarTheme.showSuccess(context, 'Saved!');
/// AppSnackbarTheme.showError(context, 'Something went wrong');
/// AppSnackbarTheme.showInfo(context, 'Loading…');
/// ```
class AppSnackbarTheme {
  AppSnackbarTheme._();

  static SnackBarThemeData get standard => SnackBarThemeData(
    backgroundColor: AppTheme.surfaceLight,
    contentTextStyle: const TextStyle(
      fontFamily: 'Poppins',
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: AppTheme.onBackground,
    ),
    actionTextColor: AppTheme.onBackground2,
    elevation: 0,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
    ),
    insetPadding: const EdgeInsets.symmetric(
      horizontal: AppTheme.md,
      vertical: AppTheme.sm,
    ),
  );

  // ── Convenience helpers ────────────────────────────────────────────────────

  static void showSuccess(BuildContext ctx, String msg) =>
      _show(ctx, msg, AppTheme.star, Icons.check_circle_outline_rounded);

  static void showError(BuildContext ctx, String msg) =>
      _show(ctx, msg, AppTheme.wishlist, Icons.error_outline_rounded);

  static void showInfo(BuildContext ctx, String msg) =>
      _show(ctx, msg, AppTheme.onBackground2, Icons.info_outline_rounded);

  static void _show(BuildContext ctx, String msg, Color accent, IconData icon) {
    ScaffoldMessenger.of(ctx)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: accent, size: 20),
              const SizedBox(width: AppTheme.sm),
              Expanded(
                child: Text(
                  msg,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: AppTheme.onBackground,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }
}
