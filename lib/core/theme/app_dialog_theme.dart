import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Dialog / bottom-sheet theme.
///
/// Register in [AppTheme.darkTheme]:
/// ```dart
/// dialogTheme: AppDialogTheme.standard,
/// ```
class AppDialogTheme {
  AppDialogTheme._();

  static DialogTheme get standard => DialogTheme(
        backgroundColor: AppTheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
        ),
        titleTextStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppTheme.onBackground,
        ),
        contentTextStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppTheme.onBackground2,
          height: 1.55,
        ),
      );

  /// Bottom sheet decoration — used with [showModalBottomSheet].
  static BoxDecoration get bottomSheetDecoration => const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXxl),
        ),
      );

  /// Register this in [ThemeData.bottomSheetTheme] if you use
  /// [showModalBottomSheet] without a custom builder.
  static BottomSheetThemeData get bottomSheet => const BottomSheetThemeData(
        backgroundColor: AppTheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalBackgroundColor: AppTheme.surface,
        modalElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusXxl),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        dragHandleColor: AppTheme.onBackground2,
        dragHandleSize: Size(40, 4),
      );
}