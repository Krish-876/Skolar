import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:Skolar/core/theme/app_theme.dart';
import 'package:Skolar/features/analytics/domain/entities/analytics_entity.dart';

class DonutProgressChart extends StatefulWidget {
  final AnalyticsData data;
  const DonutProgressChart({super.key, required this.data});

  @override
  State<DonutProgressChart> createState() => _DonutProgressChartState();
}

class _DonutProgressChartState extends State<DonutProgressChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _reveal;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _reveal = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.forward();
    });
  }

  @override
void didUpdateWidget(DonutProgressChart oldWidget) {
  super.didUpdateWidget(oldWidget);
  _controller.forward(from: 0);
}

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.surfaceGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Task Progress',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: AppTheme.textPrimary),
              ),
              Icon(Icons.more_horiz, color: AppTheme.textSecondary),
            ],
          ),

          const SizedBox(height: 24),

          // ── Rings + center label ──────────────────────────────────────
          SizedBox(
            height: 220,
            child: AnimatedBuilder(
              animation: _reveal,
              builder: (context, _) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // CustomPainter draws the three concentric arcs
                    Center(
                      child: CustomPaint(
                        size: const Size(220, 220),
                        painter: _ConcentricRingsPainter(
                          progress: _reveal.value,
                          todoPercent: widget.data.todoPercent,
                          inProgressPercent: widget.data.inProgressPercent,
                          completedPercent: widget.data.completedPercent,
                          trackColor: AppTheme.surface.withOpacity(0.4),
                          todoColor: AppTheme.chartTodo,
                          inProgressColor: AppTheme.chartInProgress,
                          completedColor: AppTheme.chartCompleted,
                        ),
                      ),
                    ),

                    // Center label fades in after rings are ~50% drawn
                    Opacity(
                      opacity: (((_reveal.value) - 0.4) / 0.6).clamp(0.0, 1.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${widget.data.totalTasksCompleted}',
                            style: Theme.of(context)
                                .textTheme
                                .displaySmall
                                ?.copyWith(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          Text(
                            'Tasks Completed',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          // ── Legend ────────────────────────────────────────────────────
          _LegendRow(data: widget.data),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Painter
// ─────────────────────────────────────────────────────────────────────────────

class _ConcentricRingsPainter extends CustomPainter {
  final double progress;       // 0.0 → 1.0 (animation value)
  final double todoPercent;
  final double inProgressPercent;
  final double completedPercent;
  final Color trackColor;
  final Color todoColor;
  final Color inProgressColor;
  final Color completedColor;

  static const double _strokeWidth = 10.0;
  static const double _gap = 10.0; // space between rings
  // Start at top (−90°) going clockwise
  static const double _startAngle = -math.pi / 2;

  _ConcentricRingsPainter({
    required this.progress,
    required this.todoPercent,
    required this.inProgressPercent,
    required this.completedPercent,
    required this.trackColor,
    required this.todoColor,
    required this.inProgressColor,
    required this.completedColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // Outermost ring = todoPercent, middle = inProgress, inner = completed
    final double outerRadius = size.width / 2 - 4;
    final double midRadius   = outerRadius - _strokeWidth - _gap;
    final double innerRadius = midRadius   - _strokeWidth - _gap;

    _drawRing(canvas, center, outerRadius, todoPercent,       todoColor);
    _drawRing(canvas, center, midRadius,   inProgressPercent, inProgressColor);
    _drawRing(canvas, center, innerRadius, completedPercent,  completedColor);
  }

  void _drawRing(
    Canvas canvas,
    Offset center,
    double radius,
    double percent,
    Color color,
  ) {
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track (full circle, dimmed)
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 2 * math.pi, false, trackPaint);

    // Arc (animated sweep)
    final sweepAngle = 2 * math.pi * percent * progress;
    if (sweepAngle <= 0) return;

    final arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, _startAngle, sweepAngle, false, arcPaint);
  }

  // Repaint only when progress changes — not on every frame
  @override
  bool shouldRepaint(_ConcentricRingsPainter old) =>
      old.progress != progress ||
      old.todoPercent != todoPercent ||
      old.inProgressPercent != inProgressPercent ||
      old.completedPercent != completedPercent;
}

// ─────────────────────────────────────────────────────────────────────────────
// Legend (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class _LegendRow extends StatelessWidget {
  final AnalyticsData data;
  const _LegendRow({required this.data});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _LegendItem(
            color: AppTheme.chartTodo,
            label: 'To Do',
            percent: data.todoPercent),
        _LegendItem(
            color: AppTheme.chartInProgress,
            label: 'In Progress',
            percent: data.inProgressPercent),
        _LegendItem(
            color: AppTheme.chartCompleted,
            label: 'Completed',
            percent: data.completedPercent),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final double percent;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.percent,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              '${(percent * 100).toStringAsFixed(0)}%',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}