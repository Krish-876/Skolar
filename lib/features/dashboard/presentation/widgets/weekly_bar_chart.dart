import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:Skolar/core/theme/app_theme.dart';
import 'package:Skolar/core/utils/semester_utils.dart';
import 'package:Skolar/core/widgets/glass_background.dart';
import 'package:Skolar/features/dashboard/domain/entities/dashboard_entity.dart';
import 'package:Skolar/features/dashboard/presentation/providers/dashboard_provider.dart';

enum WeeklyChartRange { week, month, semester }

class ChartPoint {
  final String label;
  final double value;
  const ChartPoint({required this.label, required this.value});
}

/// Bucketed week/month/semester chart data, derived from
/// [progressStatsProvider]. This used to be recomputed inline in
/// `ExpandableProgressCard`'s `_ExpandedContent.build()` — cheap in
/// isolation (a 30-entry fold/sublist/DateFormat pass), but that widget
/// rebuilds on every single frame of the card's expand/collapse drag
/// animation (its `radius`/`lineWidth` change continuously), so the same
/// bucketing work was redone dozens of times per drag for data that never
/// actually changes mid-gesture. A plain `Provider` only reruns its build
/// when something it watches (`progressStatsProvider`) actually changes —
/// here, once, when the stats finish loading — so every one of those
/// per-frame rebuilds now just reads the same cached `Map` instead of
/// recomputing it.
final weeklyChartDataProvider =
    Provider<Map<WeeklyChartRange, List<ChartPoint>>>((ref) {
      final stats = ref.watch(progressStatsProvider).valueOrNull;
      if (stats == null) return const {};
      return _bucketChartData(stats.dailyCompletions);
    });

Map<WeeklyChartRange, List<ChartPoint>> _bucketChartData(
  List<DailyCompletion> days,
) {
  final week = days.length >= 7 ? days.sublist(days.length - 7) : days;

  final monthBuckets = <ChartPoint>[];
  for (var i = 0; i < days.length; i += 7) {
    final bucket = days.skip(i).take(7);
    final sum = bucket.fold<int>(0, (a, d) => a + d.sessionCount);
    monthBuckets.add(
      ChartPoint(label: 'W${monthBuckets.length + 1}', value: sum.toDouble()),
    );
  }

  // Real monthly buckets across the active semester
  final (semStart, semEnd) = semesterRangeFromTerms();
  final semester = <ChartPoint>[];
  for (var m = semStart.month; m <= semEnd.month; m++) {
    final monthSessions = days
        .where((d) => d.date.year == semStart.year && d.date.month == m)
        .fold<int>(0, (a, d) => a + d.sessionCount);
    final monthLabel = DateFormat('MMM').format(DateTime(semStart.year, m, 1));
    semester.add(
      ChartPoint(label: monthLabel, value: monthSessions.toDouble()),
    );
  }

  return {
    WeeklyChartRange.week: week
        .map(
          (d) => ChartPoint(
            label: DateFormat('E').format(d.date).substring(0, 1),
            value: d.sessionCount.toDouble(),
          ),
        )
        .toList(),
    WeeklyChartRange.month: monthBuckets,
    WeeklyChartRange.semester: semester,
  };
}

/// Bar chart with muted bars, one highlighted selected bar, a floating
/// tooltip above it, and Week/Month/Semester range chips. There is no
/// history to fill a 1Y/All range, so only these three are offered.
class WeeklyBarChart extends StatefulWidget {
  final Map<WeeklyChartRange, List<ChartPoint>> dataByRange;

  const WeeklyBarChart({super.key, required this.dataByRange});

  @override
  State<WeeklyBarChart> createState() => _WeeklyBarChartState();
}

class _WeeklyBarChartState extends State<WeeklyBarChart> {
  WeeklyChartRange _range = WeeklyChartRange.week;
  late int _selectedIndex = _points.length - 1;

  List<ChartPoint> get _points => widget.dataByRange[_range] ?? const [];

  void _selectRange(WeeklyChartRange range) {
    setState(() {
      _range = range;
      _selectedIndex = _points.length - 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final points = _points;
    final selectedIndex = _selectedIndex
        .clamp(0, math.max(points.length - 1, 0))
        .toInt();
    final maxY = points.isEmpty
        ? 1.0
        : points.map((p) => p.value).reduce(math.max) * 1.35;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      // Glassmorphic card — same blurred, whitish-translucent-edge treatment
      // as the "All-Round Development" card elsewhere on this dashboard
      // (see `GlassCard`), replacing the previous flat surface gradient.
      child: GlassCard(
        borderRadius: 20,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                switch (_range) {
                  WeeklyChartRange.week => 'Weekly Progress',
                  WeeklyChartRange.month => 'Monthly Progress',
                  WeeklyChartRange.semester => 'Semester Progress',
                },
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontFamily: 'GoogleSans',
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              // Horizontally scrollable rather than a plain Row: on narrow
              // screens/larger text scales the three chips' combined natural
              // width can exceed the card's content width, and a plain Row (no
              // Expanded/Wrap) overflows instead of shrinking.
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: WeeklyChartRange.values
                      .map(
                        (r) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _RangeChip(
                            label: switch (r) {
                              WeeklyChartRange.week => 'Week',
                              WeeklyChartRange.month => 'Month',
                              WeeklyChartRange.semester => 'Semester',
                            },
                            selected: r == _range,
                            onTap: () => _selectRange(r),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 24),
              if (points.isEmpty)
                const SizedBox(height: 160)
              else
                SizedBox(
                  height: 180,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final slotWidth = constraints.maxWidth / points.length;
                      final tooltipLeft =
                          (selectedIndex + 0.5) * slotWidth - 34;
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 28),
                            child: BarChart(
                              BarChartData(
                                maxY: maxY,
                                alignment: BarChartAlignment.spaceAround,
                                gridData: const FlGridData(show: false),
                                borderData: FlBorderData(show: false),
                                barTouchData: BarTouchData(
                                  enabled: true,
                                  touchTooltipData: BarTouchTooltipData(
                                    getTooltipColor: (_) =>
                                        AppTheme.transparent,
                                    tooltipPadding: EdgeInsets.zero,
                                    getTooltipItem: (_, _, _, _) => null,
                                  ),
                                  touchCallback: (event, response) {
                                    final index =
                                        response?.spot?.touchedBarGroupIndex;
                                    if (event.isInterestedForInteractions &&
                                        index != null) {
                                      setState(() => _selectedIndex = index);
                                    }
                                  },
                                ),
                                titlesData: FlTitlesData(
                                  leftTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  topTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  rightTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, _) {
                                        final idx = value.toInt();
                                        if (idx < 0 || idx >= points.length) {
                                          return const SizedBox.shrink();
                                        }
                                        final isSelected = idx == selectedIndex;
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            top: 8,
                                          ),
                                          child: Text(
                                            points[idx].label,
                                            style: TextStyle(
                                              fontFamily: 'GoogleSans',
                                              color: isSelected
                                                  ? AppTheme.textPrimary
                                                  : AppTheme.textSecondary,
                                              fontSize: 11,
                                              fontWeight: isSelected
                                                  ? FontWeight.w700
                                                  : FontWeight.w400,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                barGroups: List.generate(points.length, (i) {
                                  final isSelected = i == selectedIndex;
                                  return BarChartGroupData(
                                    x: i,
                                    barRods: [
                                      BarChartRodData(
                                        toY: points[i].value,
                                        width: 14,
                                        borderRadius: BorderRadius.circular(4),
                                        color: isSelected
                                            ? AppTheme.accent
                                            : AppTheme.surfaceLight,
                                      ),
                                    ],
                                  );
                                }),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            left: tooltipLeft.clamp(
                              0.0,
                              math.max(0.0, constraints.maxWidth - 68),
                            ),
                            child: _FloatingTooltip(
                              value: points[selectedIndex].value
                                  .toStringAsFixed(0),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FloatingTooltip extends StatelessWidget {
  final String value;
  const _FloatingTooltip({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.accent,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        value,
        style: const TextStyle(
          fontFamily: 'GoogleSans',
          color: AppTheme.onPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RangeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RangeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accent : AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'GoogleSans',
            color: selected ? AppTheme.onPrimary : AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
