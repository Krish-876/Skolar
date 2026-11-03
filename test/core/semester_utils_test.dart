import 'package:flutter_test/flutter_test.dart';
import 'package:Skolar/core/utils/semester_utils.dart';

void main() {
  group('semester_utils tests', () {
    test('monthEnd computes correct dynamic last day without hardcoding', () {
      // Non-leap year February (2025): 28 days
      expect(monthEnd(2025, 2), DateTime(2025, 2, 28));

      // Leap year February (2024): 29 days
      expect(monthEnd(2024, 2), DateTime(2024, 2, 29));

      // 30-day month (April): 30 days
      expect(monthEnd(2026, 4), DateTime(2026, 4, 30));

      // 31-day month (May): 31 days
      expect(monthEnd(2026, 5), DateTime(2026, 5, 31));

      // December: 31 days
      expect(monthEnd(2026, 12), DateTime(2026, 12, 31));
    });

    test('May (even) semester range', () {
      final mayDate = DateTime(2026, 5, 15);
      final (start, end) = semesterRangeFromTerms(
        evenStart: 1,
        evenEnd: 5,
        oddStart: 8,
        oddEnd: 12,
        now: mayDate,
      );
      expect(start, DateTime(2026, 1, 1));
      expect(end, DateTime(2026, 5, 31));
      expect(isHolidayGap(mayDate.month, evenEnd: 5, oddStart: 8), isFalse);
    });

    test('June (holiday gap - strictly between evenEnd 5 and oddStart 8)', () {
      final juneDate = DateTime(2026, 6, 10);
      expect(isHolidayGap(juneDate.month, evenEnd: 5, oddStart: 8), isTrue);

      // Decision 4: Holiday gap shows most recently ended semester (Even semester Jan-May)
      final (start, end) = semesterRangeFromTerms(
        evenStart: 1,
        evenEnd: 5,
        oddStart: 8,
        oddEnd: 12,
        now: juneDate,
      );
      expect(start, DateTime(2026, 1, 1));
      expect(end, DateTime(2026, 5, 31));
    });

    test('July (holiday gap - strictly between evenEnd 5 and oddStart 8)', () {
      final julyDate = DateTime(2026, 7, 20);
      expect(isHolidayGap(julyDate.month, evenEnd: 5, oddStart: 8), isTrue);

      // Decision 4: Holiday gap shows most recently ended semester (Even semester Jan-May)
      final (start, end) = semesterRangeFromTerms(
        evenStart: 1,
        evenEnd: 5,
        oddStart: 8,
        oddEnd: 12,
        now: julyDate,
      );
      expect(start, DateTime(2026, 1, 1));
      expect(end, DateTime(2026, 5, 31));
    });

    test('August (odd) semester range', () {
      final augDate = DateTime(2026, 8, 1);
      expect(isHolidayGap(augDate.month, evenEnd: 5, oddStart: 8), isFalse);

      final (start, end) = semesterRangeFromTerms(
        evenStart: 1,
        evenEnd: 5,
        oddStart: 8,
        oddEnd: 12,
        now: augDate,
      );
      expect(start, DateTime(2026, 8, 1));
      expect(end, DateTime(2026, 12, 31));
    });
  });
}
