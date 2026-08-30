import 'package:flutter/material.dart';
import 'package:Skolar/core/theme/app_theme.dart';

abstract class FeedColors {
  // Backgrounds
  static const scaffold = AppTheme.background;
  static const topBar = AppTheme.background;
  static const surface = AppTheme.surface;
  static const surfaceLight = AppTheme.surfaceLight;
  static const inputBg = AppTheme.surface;

  // Borders
  static const border = AppTheme.onboardingButtonBorder;
  static const borderSoft = Color(0x1FFFFFFF);
  static const borderTag = Color(0x1FFFFFFF);
  static const borderSubj = Color(0x33B388FF);

  // Text
  static const textPrimary = AppTheme.onBackground;
  static const textSecondary = AppTheme.onBackground2;
  static const textMuted = Color(0xFF8E8E96);
  static const textHint = Color(0xFF6B6675);

  // Accent
  static const purple = AppTheme.accentPurple;
  static const purpleDark = AppTheme.accentPurpleDark;
  static const upvoteOn = Color(0xFFFF7A00);
  static const downvoteOn = Color(0xFF5B6EF5);

  // Tags
  static const tagSubjBg = Color(0x1EB388FF);
  static const tagSubjText = AppTheme.accentPurple;
  static const tagBg = AppTheme.surfaceLight;
  static const tagText = AppTheme.onBackground2;

  // Difficulty dots & text
  static const dotEasy = Color(0xFF4CAF50);
  static const dotMedium = Color(0xFFF5C518);
  static const dotHard = Color(0xFFFF5252);
  static const textEasy = Color(0xFF81C784);
  static const textMedium = Color(0xFFFFD54F);
  static const textHard = Color(0xFFFF8A80);

  // Attempt button
  static const attemptBorder = AppTheme.accentPurpleDark;
  static const attemptText = AppTheme.onPrimary;
  static const attemptHover = AppTheme.accentPurple;

  // Sort sheet
  static const sheetBg = AppTheme.surface;
  static const sheetHandle = Color(0x33FFFFFF);
  static const sortOptBorder = Color(0x14FFFFFF);
  static const sortSelText = AppTheme.accentPurple;
  static const sortOptHover = AppTheme.surfaceLight;

  /// Returns card surface color
  static Color cardShade(int index) {
    return AppTheme.surface;
  }

  /// Returns difficulty dot colour.
  static Color diffDot(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return dotEasy;
      case 'hard':
        return dotHard;
      default:
        return dotMedium;
    }
  }

  /// Returns difficulty text colour.
  static Color diffText(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return textEasy;
      case 'hard':
        return textHard;
      default:
        return textMedium;
    }
  }
}
