import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_theme.dart';

/// AppBar theme variants.
///
/// Register in [AppTheme.darkTheme]:
/// ```dart
/// appBarTheme: AppAppBarTheme.standard,
/// ```
class AppAppBarTheme {
  AppAppBarTheme._();

  /// Default — transparent, no elevation, white status-bar icons.
  /// Matches every screen in the design (the background gradient shows through).
  static AppBarTheme get standard => AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        foregroundColor: AppTheme.onBackground,
        iconTheme: const IconThemeData(
          color: AppTheme.onBackground,
          size: 22,
        ),
        actionsIconTheme: const IconThemeData(
          color: AppTheme.onBackground2,
          size: 22,
        ),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,   // white icons on dark bg
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: AppTheme.background,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      );

  /// Surface-coloured variant — used on screens that don't use a full
  /// background gradient (e.g. deep-nested settings pages).
  static AppBarTheme get surface => standard.copyWith(
        backgroundColor: AppTheme.surface,
      );
}