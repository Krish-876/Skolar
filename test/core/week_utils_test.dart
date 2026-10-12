import 'package:flutter_test/flutter_test.dart';
import 'package:Skolar/core/utils/week_utils.dart';

void main() {
  group('week_utils tests', () {
    test('standard Sunday start (startDay = 7)', () {
      // 2026-10-05 is a Monday. Week should start on Sunday 2026-10-04.
      final monday = DateTime(2026, 10, 5);
      final start = weekStartFor(monday, 7);
      expect(start, DateTime(2026, 10, 4));

      // 2026-10-04 is Sunday. Week should start on Sunday 2026-10-04.
      final sunday = DateTime(2026, 10, 4);
      expect(weekStartFor(sunday, 7), DateTime(2026, 10, 4));

      // 2026-10-10 is Saturday. Week should start on Sunday 2026-10-04.
      final saturday = DateTime(2026, 10, 10);
      expect(weekStartFor(saturday, 7), DateTime(2026, 10, 4));
    });

    test('Monday start (startDay = 1)', () {
      // 2026-10-05 is Monday. Week starts on 2026-10-05.
      final monday = DateTime(2026, 10, 5);
      expect(weekStartFor(monday, 1), DateTime(2026, 10, 5));

      // 2026-10-11 is Sunday. Week starts on Monday 2026-10-05.
      final sunday = DateTime(2026, 10, 11);
      expect(weekStartFor(sunday, 1), DateTime(2026, 10, 5));
    });

    test('custom start days across all ISO weekdays 1..7', () {
      final target = DateTime(2026, 10, 7); // Wednesday (weekday 3)
      for (int day = 1; day <= 7; day++) {
        final start = weekStartFor(target, day);
        expect(start.weekday, day);
        expect(start.isAfter(target), isFalse);
        final diffDays = target.difference(start).inDays;
        expect(diffDays >= 0 && diffDays < 7, isTrue);
      }
    });

    test('year boundary calculation', () {
      // 2026-01-01 is Thursday (weekday 4).
      // With Sunday start (7), week started in previous year: 2025-12-28.
      final jan1 = DateTime(2026, 1, 1);
      final startSun = weekStartFor(jan1, 7);
      expect(startSun, DateTime(2025, 12, 28));

      // With Monday start (1), week started on 2025-12-29.
      final startMon = weekStartFor(jan1, 1);
      expect(startMon, DateTime(2025, 12, 29));
    });

    test('DST-safe: always produces midnight 00:00:00 without hour drift', () {
      final date = DateTime(2026, 3, 29, 0, 0, 0);
      final start = weekStartFor(date, 7);
      expect(start.hour, 0);
      expect(start.minute, 0);
      expect(start.second, 0);
    });
  });
}
