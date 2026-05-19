import 'package:flutter/material.dart';

abstract class FeedColors {
  // Backgrounds
  static const scaffold   = Color(0xFF0D0E10);
  static const topBar     = Color(0xFF111214);
  static const cardShade1 = Color(0xFF14151A);
  static const cardShade2 = Color(0xFF111318);
  static const cardShade3 = Color(0xFF131419);
  static const cardShade4 = Color(0xFF121318);
  static const cardShade5 = Color(0xFF131217);
  static const surface    = Color(0xFF16171C);
  static const inputBg    = Color(0xFF0D0E10);

  // Borders
  static const border     = Color(0xFF1C1D21);
  static const borderSoft = Color(0xFF17181C);
  static const borderTag  = Color(0xFF2A2B33);
  static const borderSubj = Color(0xFF2D2B46);

  // Text
  static const textPrimary   = Color(0xFFE2E3EA);
  static const textSecondary = Color(0xFFB0B2BC);
  static const textMuted     = Color(0xFF7A7C86);
  static const textHint      = Color(0xFF555760);

  // Accent
  static const purple     = Color(0xFF7F77DD);
  static const purpleDark = Color(0xFF534AB7);
  static const upvoteOn   = Color(0xFFFF6314);
  static const downvoteOn = Color(0xFF6A8CCA);

  // Tags
  static const tagSubjBg   = Color(0xFF1A1A2E);
  static const tagSubjText = Color(0xFF8A84C9);
  static const tagBg       = Color(0xFF1E1F28);
  static const tagText     = Color(0xFF7A7C86);

  // Difficulty dots
  static const dotEasy   = Color(0xFF4A9E6A);
  static const dotMedium = Color(0xFFB8860B);
  static const dotHard   = Color(0xFF8B3A3A);
  static const textEasy   = Color(0xFF7ABF97);
  static const textMedium = Color(0xFFC9A44A);
  static const textHard   = Color(0xFFB06060);

  // Bottom nav
  static const navActive   = Color(0xFF7F77DD);
  static const navInactive = Color(0xFF555760);
  static const navBg       = Color(0xFF111214);
  static const genRingBg   = Color(0xFF1A1B22);
  static const genRingBorder = Color(0xFF2A2B35);

  // Attempt button
  static const attemptBorder = Color(0xFF2D2B46);
  static const attemptText   = Color(0xFF8A84C9);
  static const attemptHover  = Color(0xFF1E1F2A);

  // Sort sheet
  static const sheetBg       = Color(0xFF16171C);
  static const sheetHandle   = Color(0xFF2C2D34);
  static const sortOptBorder = Color(0xFF1E1F24);
  static const sortSelText   = Color(0xFF7F77DD);
  static const sortOptHover  = Color(0xFF1E1F26);

  /// Returns the shade for card at index (cycles through 5 shades).
  static Color cardShade(int index) {
    const shades = [cardShade1, cardShade2, cardShade3, cardShade4, cardShade5];
    return shades[index % shades.length];
  }

  /// Returns difficulty dot colour.
  static Color diffDot(String difficulty) {
    switch (difficulty) {
      case 'easy':   return dotEasy;
      case 'hard':   return dotHard;
      default:       return dotMedium;
    }
  }

  /// Returns difficulty text colour.
  static Color diffText(String difficulty) {
    switch (difficulty) {
      case 'easy':   return textEasy;
      case 'hard':   return textHard;
      default:       return textMedium;
    }
  }
}