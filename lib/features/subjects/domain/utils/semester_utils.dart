/// Single source of truth for "what semester is it right now".
///
/// Odd semester (1): June – December.
/// Even semester (2): January – May.
///
/// May is the end of the even semester's comprehensive exams, so June
/// onward — even before classes physically resume — already counts as
/// the next (odd) semester. This must be the ONLY place this logic
/// lives; both onboarding (which seeds user_subjects) and the subjects
/// page (which queries user_subjects) call this so their semester
/// labels can never drift apart.
class SemesterUtils {
  static int currentSemesterNumber([DateTime? now]) {
    final month = (now ?? DateTime.now()).month;
    return month <= 5 ? 2 : 1;
  }

  /// e.g. "2026-S1"
  static String currentSemesterLabel([DateTime? now]) {
    final n = now ?? DateTime.now();
    return '${n.year}-S${currentSemesterNumber(n)}';
  }

  /// Returns the inclusive [start, end] date range for the semester that
  /// contains [now] (or today when omitted).
  ///
  /// Even (2): Jan 1 – May 31 of the same year.
  /// Odd  (1): Jun 1 – Dec 31 of the same year.
  ///
  /// This is the canonical semester-range computation. Any code that
  /// needs to filter Supabase rows by semester should call this rather
  /// than inlining the month boundaries.
  static (DateTime start, DateTime end) semesterRange([DateTime? now]) {
    final n = now ?? DateTime.now();
    if (currentSemesterNumber(n) == 2) {
      // Even semester: January → May
      return (DateTime(n.year, 1, 1), DateTime(n.year, 5, 31));
    } else {
      // Odd semester: June → December
      return (DateTime(n.year, 6, 1), DateTime(n.year, 12, 31));
    }
  }
}
