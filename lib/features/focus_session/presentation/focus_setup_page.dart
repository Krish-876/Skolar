import 'package:Skolar/core/theme/app_theme.dart';
import 'package:Skolar/features/focus_session/data/models/focus_present.dart';
import 'package:Skolar/features/focus_session/widgets/focus_background.dart';
import 'package:Skolar/features/focus_session/widgets/glow_thumb_shape.dart';
import 'package:Skolar/features/focus_session/widgets/present_chip.dart';
import 'package:flutter/material.dart';

class FocusSetupPage extends StatefulWidget {
  final void Function(int seconds) onConfirm;
  final int initialSeconds;

  const FocusSetupPage({
    super.key,
    required this.onConfirm,
    this.initialSeconds = 3600,
  });

  @override
  State<FocusSetupPage> createState() => _FocusSetupPageState();
}

class _FocusSetupPageState extends State<FocusSetupPage> {
  late int _selectedSeconds;
  int? _activePresetIndex;

  static const int _minMinutes = 1;
  static const int _maxMinutes = 180;

  int get _selectedMinutes => _selectedSeconds ~/ 60;

  @override
  void initState() {
    super.initState();
    _selectedSeconds = widget.initialSeconds;
    _activePresetIndex = _matchPreset(_selectedSeconds);
  }

  int? _matchPreset(int seconds) {
    for (int i = 0; i < FocusPreset.defaults.length; i++) {
      if (FocusPreset.defaults[i].seconds == seconds) return i;
    }
    return null;
  }

  void _selectPreset(int index) {
    setState(() {
      _activePresetIndex = index;
      _selectedSeconds = FocusPreset.defaults[index].seconds;
    });
  }

  void _onSliderChanged(double value) {
    final minutes = value.round();
    setState(() {
      _selectedSeconds = minutes * 60;
      _activePresetIndex = _matchPreset(_selectedSeconds);
    });
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          const FocusBackground(slideProgress: 0.0),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAppBar(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.lg,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: AppTheme.xl),
                        _buildHeroTime(),
                        const SizedBox(height: AppTheme.xxl),
                        _buildSectionLabel('QUICK PRESETS'),
                        const SizedBox(height: AppTheme.md),
                        _buildPresetChips(),
                        const SizedBox(height: AppTheme.xl),
                        _buildSectionLabel('CUSTOM DURATION'),
                        const SizedBox(height: AppTheme.sm),
                        _buildSliderRow(),
                        const SizedBox(height: AppTheme.xxl),
                        _buildSessionInfoCard(),
                        const SizedBox(height: AppTheme.xl),
                        _buildConfirmButton(),
                        const SizedBox(height: AppTheme.xxl),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.md,
        vertical: AppTheme.sm,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: const Icon(
                Icons.chevron_left_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.md),
          Text(
            'Set focus duration',
            style: TextStyle(
              fontFamily: 'GoogleSans',
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroTime() {
    return Center(
      child: Column(
        children: [
          ShaderMask(
            shaderCallback: (bounds) =>
                AppTheme.textGradient.createShader(bounds),
            child: Text(
              _formatDuration(_selectedSeconds),
              style: TextStyle(
                fontFamily: 'GoogleSans',
                color: Colors.white,
                fontSize: 80,
                fontWeight: FontWeight.w700,
                letterSpacing: -3,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: AppTheme.sm),
          Text(
            'focus session',
            style: TextStyle(
              fontFamily: 'GoogleSans',
              color: AppTheme.onBackground2.withValues(alpha: 0.7),
              fontSize: 15,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'GoogleSans',
        color: AppTheme.accentPurple,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.4,
      ),
    );
  }

  Widget _buildPresetChips() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List.generate(FocusPreset.defaults.length, (i) {
        final preset = FocusPreset.defaults[i];
        final isActive = _activePresetIndex == i;
        return PresetChip(
          label: preset.label,
          isActive: isActive,
          onTap: () => _selectPreset(i),
        );
      }),
    );
  }

  Widget _buildSliderRow() {
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const GlowThumbShape(),
            overlayShape: SliderComponentShape.noOverlay,
            activeTrackColor: AppTheme.primary,
            inactiveTrackColor: AppTheme.surface,
            thumbColor: Colors.white,
          ),
          child: Slider(
            value: _selectedMinutes.toDouble(),
            min: _minMinutes.toDouble(),
            max: _maxMinutes.toDouble(),
            divisions: _maxMinutes - _minMinutes,
            onChanged: _onSliderChanged,
          ),
        ),
        const SizedBox(height: AppTheme.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_minMinutes}m',
              style: TextStyle(
                fontFamily: 'GoogleSans',
                color: Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${_maxMinutes ~/ 60}h',
              style: TextStyle(
                fontFamily: 'GoogleSans',
                color: Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSessionInfoCard() {
    final h = _selectedSeconds ~/ 3600;
    final m = (_selectedSeconds % 3600) ~/ 60;
    final pomodoroCount = (_selectedSeconds / (25 * 60)).floor();

    return Container(
      padding: const EdgeInsets.all(AppTheme.md),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: const Icon(
              Icons.timer_outlined,
              color: AppTheme.accentPurple,
              size: 22,
            ),
          ),
          const SizedBox(width: AppTheme.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Session breakdown',
                  style: TextStyle(
                    fontFamily: 'GoogleSans',
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _buildBreakdownText(h, m, pomodoroCount),
                  style: TextStyle(
                    fontFamily: 'GoogleSans',
                    color: Colors.white60,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _buildBreakdownText(int h, int m, int pomodoroCount) {
    final parts = <String>[];
    if (h > 0) parts.add('$h hour${h > 1 ? 's' : ''}');
    if (m > 0) parts.add('$m minute${m > 1 ? 's' : ''}');
    final timeStr = parts.join(' and ');
    if (pomodoroCount > 0) {
      return '$timeStr · ~$pomodoroCount pomodoro${pomodoroCount > 1 ? 's' : ''}';
    }
    return timeStr;
  }

  Widget _buildConfirmButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.38),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: () => widget.onConfirm(_selectedSeconds),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            ),
          ),
          child: Text(
            'Start session →',
            style: TextStyle(
              fontFamily: 'GoogleSans',
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}
