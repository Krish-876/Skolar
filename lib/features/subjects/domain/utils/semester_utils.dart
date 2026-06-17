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
}