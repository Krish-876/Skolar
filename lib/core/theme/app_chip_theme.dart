import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Chip theme — used for category tags, filter pills, day-streak badges.
///
/// Register in [AppTheme.darkTheme]:
/// ```dart
/// chipTheme: AppChipTheme.standard,
/// ```
class AppChipTheme {
  AppChipTheme._();

  static ChipThemeData get standard => ChipThemeData(
        backgroundColor: AppTheme.surfaceLight,
        selectedColor: AppTheme.primary,
        disabledColor: AppTheme.surface,
        deleteIconColor: AppTheme.onBackground2,
        labelStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppTheme.onBackground,
        ),
        secondaryLabelStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppTheme.onPrimary,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.sm,
          vertical: AppTheme.xs,
        ),
        shape: const StadiumBorder(),
        side: BorderSide.none,
        elevation: 0,
        pressElevation: 0,
        shadowColor: Colors.transparent,
        showCheckmark: false,
        iconTheme: const IconThemeData(
          color: AppTheme.onBackground2,
          size: 16,
        ),
      );

  /// Streak-day dot chip — Mon / Tue / Wed circles on Profile screen.
  static ChipThemeData get streakDay => standard.copyWith(
        backgroundColor: AppTheme.surface,
        selectedColor: AppTheme.wishlist,   // red filled = completed day
        padding: const EdgeInsets.all(AppTheme.xs),
        shape: const CircleBorder(),
        labelStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 10,
          color: AppTheme.onBackground2,
        ),
      );
}