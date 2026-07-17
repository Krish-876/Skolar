import 'package:flutter/material.dart';

/// Application theme configuration
class AppTheme {
  // ── Core Brand Colors ──────────────────────────────────────────────────────
  static const Color background = Colors.black; // Background
  static const Color primary = Color(0xFF1E2A8A); // Primary (deep blue)
  static const Color secondary = Color(0xFF050610); // Secondary (near-black)
  static const Color star = Color(0xFFF5C518); // Star / highlight yellow
  static const Color wishlist = Color(0xFFD0021B); // Wishlist / danger red
  static const Color accentPurple = Color(0xFFB388FF); // Skolar brand purple

  // ── Surface & Overlay ─────────────────────────────────────────────────────
  static const Color surface = Color(0xFF2E2B3E); // Surface (purple-gray)
  static const Color onBackground = Color(0xFFFFFFFF); // Text on background
  static const Color onSecondary = Color(0xFFFFFFFF); // Text on secondary
  static const Color onPrimary = Color(0xFFFFFFFF); // Text on primary
  static const Color onSurface = Color(0xFFFFFFFF); // Text on surface
  static const Color onSurfaceDark = Color(
    0xFF000000,
  ); // Dark text on light surface
  static const Color onBackground2 = Color(
    0xFFA8C4FF,
  ); // Secondary text / light blue
  static const Color surfaceLight = Color(
    0xFF3A3750,
  ); // Lighter surface variant

  // ── Gradients (represented as begin color → end color) ────────────────────
  // Use with LinearGradient in widgets
  static const Color primaryGradBegin = Color(0xFF1E2A8A);
  static const Color primaryGradEnd = Color(0xFF2E3DA0);
  static const Color bgGradBegin = Color(0xFF0D1440); // Background gradient top
  static const Color bgGradEnd = Color(
    0xFF000005,
  ); // Background gradient bottom
  static const Color surfaceGradBegin = Color(
    0xFF0D1B3E,
  ); // Surface gradient top
  static const Color surfaceGradEnd = Color(
    0xFF05061A,
  ); // Surface gradient bottom
  static const Color textGradBegin = Color(0xFFD0DFFF); // Text gradient light
  static const Color textGradEnd = Color(0xFFFFFFFF); // Text gradient white

  // ── Utility ────────────────────────────────────────────────────────────────
  static const Color blur = Color(0x33FFFFFF); // Frosted glass / blur
  static const Color dropShadow = Color(0x40000000); // Drop shadow

  // ── Spacing ────────────────────────────────────────────────────────────────
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  // ── Border Radius ──────────────────────────────────────────────────────────
  static const double radiusSm = 4;
  static const double radiusMd = 8;
  static const double radiusLg = 12;
  static const double radiusXl = 16;
  static const double radiusXxl = 24;

  // ── Surface gradient (focus panel) ────────────────────────────────────────
  static const Color surfaceGrad2Begin = Color.fromARGB(255, 33, 45, 79);
  static const Color surfaceGrad2End = Color(0x9920223C);

  // ── Reusable Gradients ─────────────────────────────────────────────────────
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bgGradBegin, bgGradEnd],
  );

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryGradBegin, primaryGradEnd],
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [surfaceGradBegin, surfaceGradEnd],
  );

  static const LinearGradient textGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [textGradEnd, textGradBegin],
  );

  static const LinearGradient surfaceGradient2 = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [surfaceGrad2Begin, surfaceGrad2End],
    stops: [0.0, 1.0],
  );

  // ── Theme Data ─────────────────────────────────────────────────────────────

  /// The app uses a single dark theme matching the design
  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: primary,
      onPrimary: onPrimary,
      secondary: secondary,
      onSecondary: onSecondary,
      surface: surface,
      onSurface: onSurface,
      error: wishlist,
      onError: onBackground,
    ),
    scaffoldBackgroundColor: background,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      foregroundColor: onBackground,
    ),
    textTheme: TextTheme(
      displayLarge: const TextStyle(
        color: onBackground,
        fontWeight: FontWeight.bold,
      ),
      displayMedium: const TextStyle(
        color: onBackground,
        fontWeight: FontWeight.bold,
      ),
      bodyLarge: const TextStyle(color: onBackground),
      bodyMedium: const TextStyle(color: onBackground2),
      bodySmall: const TextStyle(color: onBackground2),
      labelLarge: const TextStyle(
        color: onPrimary,
        fontWeight: FontWeight.w600,
      ),
    ),
    // cardTheme: CardTheme(
    //   color: surface,
    //   elevation: 0,
    //   shape: RoundedRectangleBorder(
    //     borderRadius: BorderRadius.circular(radiusXl),
    //   ),
    // ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXl),
        ),
      ),
    ),
    iconTheme: const IconThemeData(color: onBackground),
    dividerColor: surface,
  );

  // Keep a lightTheme stub so existing imports don't break,
  // but the app should always use darkTheme.
  static ThemeData get lightTheme => darkTheme;

  static Color? get divider => null;
  // ── Dashboard specific ─────────────────────────────────────────────────────
  static const Color cardBackground = Color(0xFF0D1440); // use surfaceGradBegin
  static const Color textPrimary = onBackground; // already have this
  static const Color textSecondary = onBackground2; // already have this
  static const Color accent = Colors.grey; // teal for charts
  static const Color dividerColor = surface; // already have this

  // ── Chart segments ────────────────────────────────────────────────────────
  static const Color chartTodo = Color(0xFF5B6EF5);
  static const Color chartInProgress = Color(0xFF63C8D4);
  static const Color chartCompleted = Color(0xFF3A3750); // use surfaceLight
  static const Color error = wishlist; // already have this
}
