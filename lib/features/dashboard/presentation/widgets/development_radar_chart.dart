import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:Skolar/core/theme/app_theme.dart';
import 'package:Skolar/features/dashboard/domain/entities/dashboard_entity.dart';

/// All-round development radar: two overlaid polygons (start-of-semester vs
/// now) over axes that come from data, never hardcoded — they will later be
/// the student's declared career units.
class DevelopmentRadarChart extends StatelessWidget {
  final List<DevelopmentAxis> axes;

  const DevelopmentRadarChart({super.key, required this.axes});

  @override
  Widget build(BuildContext context) {
    if (axes.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 260,
      child: RadarChart(
        RadarChartData(
          radarShape: RadarShape.polygon,
          tickCount: 4,
          radarBackgroundColor: AppTheme.transparent,
          radarBorderData: BorderSide(
            color: AppTheme.divider ?? AppTheme.surface,
          ),
          gridBorderData: BorderSide(
            color: AppTheme.surfaceLight.withValues(alpha: 0.5),
            width: 1,
          ),
          tickBorderData: const BorderSide(color: AppTheme.transparent),
          ticksTextStyle: const TextStyle(
            color: AppTheme.transparent,
            fontSize: 0,
          ),
          titleTextStyle: TextStyle(
            fontFamily: 'GoogleSans',
            color: AppTheme.textSecondary.withValues(alpha: 0.6),
            fontSize: 11,
          ),
          titlePositionPercentageOffset: 0.14,
          getTitle: (index, angle) =>
              RadarChartTitle(text: axes[index].label, angle: angle),
          dataSets: [
            RadarDataSet(
              dataEntries: axes
                  .map((a) => RadarEntry(value: a.startOfSemester))
                  .toList(),
              fillColor: AppTheme.surfaceLight.withValues(alpha: 0.35),
              borderColor: AppTheme.textSecondary,
              borderWidth: 1.5,
              entryRadius: 2,
            ),
            RadarDataSet(
              dataEntries: axes.map((a) => RadarEntry(value: a.now)).toList(),
              fillColor: AppTheme.accent.withValues(alpha: 0.35),
              borderColor: AppTheme.accent,
              borderWidth: 2,
              entryRadius: 3,
            ),
          ],
        ),
      ),
    );
  }
}
