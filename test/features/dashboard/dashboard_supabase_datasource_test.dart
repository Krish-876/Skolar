import 'package:flutter_test/flutter_test.dart';
import 'package:Skolar/core/utils/semester_utils.dart';
import 'package:Skolar/core/utils/week_utils.dart';
import 'package:Skolar/features/dashboard/data/dtos/dashboard_dto.dart';

void main() {
  group('DashboardSupabaseDataSource aggregation tests', () {
    test(
      'aggregates week total, semester total, and straddling week correctly',
      () {
        // Setup dates:
        // Suppose current date is Jan 5, 2026 (Monday).
        // Week start is Sunday, Jan 4, 2026.
        // Semester start is Jan 1, 2026.
        final today = DateTime(2026, 1, 5);
        final weekStart = weekStartFor(today, 7); // 2026-01-04
        final weekEnd = DateTime(
          weekStart.year,
          weekStart.month,
          weekStart.day + 6,
        ); // 2026-01-10
        final (semStart, semEnd) = semesterRangeFromTerms(
          now: today,
        ); // 2026-01-01 to 2026-05-31

        // Simulated RPC output rows:
        final rawRpcRows = [
          {
            'day': '2025-12-30',
            'sessions': 1,
            'counted_focus_seconds': 1800,
          }, // Before semester & before week
          {
            'day': '2026-01-02',
            'sessions': 2,
            'counted_focus_seconds': 3600,
          }, // In semester, but before this week
          {
            'day': '2026-01-04',
            'sessions': 1,
            'counted_focus_seconds': 2400,
          }, // In semester AND in this week (Sunday)
          {
            'day': '2026-01-05',
            'sessions': 2,
            'counted_focus_seconds': 3000,
          }, // In semester AND in this week (Monday)
        ];

        final daily = rawRpcRows
            .map((r) => ActivityDailyRowDto.fromJson(r))
            .toList();

        // Semester total: rows within [semStart, semEnd]
        int semesterSeconds = 0;
        for (final r in daily) {
          final d = DateTime.parse(r.day);
          if (!d.isBefore(semStart) && !d.isAfter(semEnd)) {
            semesterSeconds += r.countedFocusSeconds;
          }
        }

        // Week total: rows within [weekStart, weekEnd]
        int weekSeconds = 0;
        for (final r in daily) {
          final d = DateTime.parse(r.day);
          if (!d.isBefore(weekStart) && !d.isAfter(weekEnd)) {
            weekSeconds += r.countedFocusSeconds;
          }
        }

        // Assertions:
        // Semester has Jan 02 (3600), Jan 04 (2400), Jan 05 (3000) = 9000 seconds = 2.5 hours
        expect(semesterSeconds, 9000);
        expect(semesterSeconds / 3600.0, 2.5);

        // Week has Jan 04 (2400) + Jan 05 (3000) = 5400 seconds = 1.5 hours
        expect(weekSeconds, 5400);
        expect(weekSeconds / 3600.0, 1.5);
      },
    );

    test(
      '30-day heatmap window populates exactly 30 entries with 0 defaults',
      () {
        final today = DateTime(2026, 1, 5);
        final rawRpcRows = [
          {'day': '2026-01-04', 'sessions': 1, 'counted_focus_seconds': 2400},
          {'day': '2026-01-05', 'sessions': 3, 'counted_focus_seconds': 3000},
        ];

        final daily = rawRpcRows
            .map((r) => ActivityDailyRowDto.fromJson(r))
            .toList();
        final dailyByDateStr = {for (final r in daily) r.day: r};

        final completions = List.generate(30, (i) {
          final dayDate = DateTime(
            today.year,
            today.month,
            today.day - (29 - i),
          );
          final dateStr =
              '${dayDate.year}-${dayDate.month.toString().padLeft(2, '0')}-${dayDate.day.toString().padLeft(2, '0')}';
          final row = dailyByDateStr[dateStr];
          return DailyCompletionDto(
            date: dateStr,
            tasksCompleted: row?.sessions ?? 0,
          );
        });

        expect(completions.length, 30);
        expect(completions.last.date, '2026-01-05');
        expect(completions.last.tasksCompleted, 3);
        expect(completions[28].date, '2026-01-04');
        expect(completions[28].tasksCompleted, 1);
        // Days with no sessions default to 0
        expect(completions[0].tasksCompleted, 0);
      },
    );
  });
}
