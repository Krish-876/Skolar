/// Pure utility functions for week-boundary calculations.
///
/// All functions are pure (no side effects, no DateTime.now()) and
/// testable without mocking.

/// Returns the start of the calendar week that contains [localDate],
/// given that weeks start on [startDay] (using Dart's [DateTime.weekday]
/// convention: 1 = Monday … 7 = Sunday).
///
/// Examples:
///   weekStartFor(DateTime(2026, 10, 5), 7) → returns DateTime(2026, 10, 4)
///   (Sunday), which is the start of the week containing Mon Oct 5, 2026.
///
/// [startDay] must be in 1..7 (matching DateTime.weekday). Sunday = 7.
DateTime weekStartFor(DateTime localDate, int startDay) {
  assert(
    startDay >= 1 && startDay <= 7,
    'startDay must be 1 (Mon) … 7 (Sun), got $startDay',
  );

  final d = DateTime(localDate.year, localDate.month, localDate.day);
  // How many days has this date moved past its own week-start?
  final dayOfWeek = d.weekday; // 1=Mon … 7=Sun
  // Compute offset: days since the most recent occurrence of startDay.
  // We work modulo-7 in a space where startDay maps to 0.
  final offset = (dayOfWeek - startDay) % 7;
  // DST-safe calendar day arithmetic:
  return DateTime(d.year, d.month, d.day - offset);
}
