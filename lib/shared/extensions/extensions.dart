import 'package:flutter/material.dart';

/// String extensions
extension StringExtension on String {
  /// Check if string is empty or whitespace
  bool get isEmptyOrWhitespace => trim().isEmpty;

  /// Capitalize first letter
  String capitalize() =>
      isEmpty ? '' : '${this[0].toUpperCase()}${substring(1)}';

  /// Check if valid email
  bool get isValidEmail {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(this);
  }
}

/// List extensions
extension ListExtension<T> on List<T> {
  /// Safe get with index
  T? safeGet(int index) {
    if (index < 0 || index >= length) return null;
    return this[index];
  }

  /// Get unique items
  List<T> get unique => toSet().toList();
}

/// Num extensions
extension NumExtension on num {
  /// Format as currency
  String toCurrency({String symbol = '\$'}) => '$symbol${toStringAsFixed(2)}';
}

/// BuildContext extensions
extension BuildContextExtension on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;
}
