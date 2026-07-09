import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Icon theme variants.
///
/// Register in [AppTheme.darkTheme]:
/// ```dart
/// iconTheme:        AppIconTheme.standard,
/// primaryIconTheme: AppIconTheme.primary,
/// ```
class AppIconTheme {
  AppIconTheme._();

  /// Default icon — white, 22 px.
  static const IconThemeData standard = IconThemeData(
    color: AppTheme.onBackground,
    size: 22,
  );

  /// Dimmed icon — used in unselected nav items, trailing chevrons.
  static const IconThemeData dimmed = IconThemeData(
    color: AppTheme.onBackground2,
    size: 22,
  );

  /// Primary-coloured icon — active states, filled nav items.
  static const IconThemeData primary = IconThemeData(
    color: AppTheme.primary,
    size: 22,
  );

  /// Star / highlight icon — wishlist, ratings.
  static const IconThemeData star = IconThemeData(
    color: AppTheme.star,
    size: 20,
  );

  /// Small icon — chips, captions, inline labels.
  static const IconThemeData small = IconThemeData(
    color: AppTheme.onBackground2,
    size: 16,
  );

  /// Large icon — hero illustrations, empty states.
  static const IconThemeData large = IconThemeData(
    color: AppTheme.onBackground,
    size: 48,
  );
}
