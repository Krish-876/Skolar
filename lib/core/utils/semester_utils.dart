/// Pure utility functions for academic terms and semester date ranges.
///
/// Month boundaries can be configured from DB (e.g. nova_config or campus config).
/// Month-end dates are computed dynamically without hardcoded 30/31 days.
library;

/// Returns the last calendar day of the given [month] in [year].
/// Computed using day 0 of the subsequent month (e.g. Day 0 of June = May 31).
DateTime monthEnd(int year, int month) => DateTime(year, month + 1, 0);

/// Determines whether [month] is in the holiday gap strictly between
/// [evenEnd] and [oddStart].
bool isHolidayGap(int month, {int evenEnd = 5, int oddStart = 8}) =>
    month > evenEnd && month < oddStart;

/// Computes the active or most recently ended semester date range.
///
/// - Even semester: [evenStart]..[evenEnd] (e.g. Jan 1 – May 31)
/// - Holiday gap (strictly between [evenEnd] and [oddStart], e.g. June, July):
///   per Decision 4, returns the most recently ended semester (Jan 1 – May 31).
/// - Odd semester: [oddStart]..[oddEnd] (e.g. Aug 1 – Dec 31)
(DateTime start, DateTime end) semesterRangeFromTerms({
  int evenStart = 1,
  int evenEnd = 5,
  int oddStart = 8,
  int oddEnd = 12,
  DateTime? now,
}) {
  final n = now ?? DateTime.now();
  final m = n.month;
  final y = n.year;

  if (m >= evenStart && m <= evenEnd) {
    // Active Even semester
    return (DateTime(y, evenStart, 1), monthEnd(y, evenEnd));
  } else if (isHolidayGap(m, evenEnd: evenEnd, oddStart: oddStart)) {
    // Holiday gap: shows the most recently ended semester (Even semester of same year)
    return (DateTime(y, evenStart, 1), monthEnd(y, evenEnd));
  } else {
    // Active Odd semester
    return (DateTime(y, oddStart, 1), monthEnd(y, oddEnd));
  }
}
