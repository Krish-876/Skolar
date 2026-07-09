import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Bottom navigation bar theme.
///
/// The design shows a dark surface bar with 5 items:
/// Home · Grid · + (FAB-style) · Chat · Profile
///
/// Register in [AppTheme.darkTheme]:
/// ```dart
/// bottomNavigationBarTheme: AppBottomNavTheme.standard,
/// ```
class AppBottomNavTheme {
  AppBottomNavTheme._();

  static BottomNavigationBarThemeData get standard =>
      const BottomNavigationBarThemeData(
        backgroundColor: AppTheme.surface,
        selectedItemColor: AppTheme.onBackground,
        unselectedItemColor: AppTheme.onBackground2,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedIconTheme: IconThemeData(
          size: 24,
          color: AppTheme.onBackground,
        ),
        unselectedIconTheme: IconThemeData(
          size: 22,
          color: AppTheme.onBackground2,
        ),
      );

  /// NavigationBar (Material 3) variant — same visual tokens.
  static NavigationBarThemeData get navigationBar => NavigationBarThemeData(
    backgroundColor: AppTheme.surface,
    indicatorColor: AppTheme.primary.withValues(alpha: 0.25),
    iconTheme: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return const IconThemeData(color: AppTheme.onBackground, size: 24);
      }
      return const IconThemeData(color: AppTheme.onBackground2, size: 22);
    }),
    labelTextStyle: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppTheme.onBackground,
        );
      }
      return const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 11,
        color: AppTheme.onBackground2,
      );
    }),
    elevation: 0,
    height: 64,
    labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
  );
}
