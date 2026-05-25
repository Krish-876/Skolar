import 'package:flutter/material.dart';
import 'package:Skolar/core/theme/app_theme.dart';
import 'package:Skolar/features/focus_session/widgets/focus_background.dart';
import 'package:Skolar/features/focus_session/widgets/focus_timer_controller.dart';
import 'package:Skolar/features/focus_session/widgets/present_chip.dart';
import 'package:Skolar/features/focus_session/widgets/glow_thumb_shape.dart';

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

  static const int _minMinutes = 5;
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
                    padding: const EdgeInsets.symmetric(horizontal: AppTheme.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: AppTheme.xl),
                        _buildHeroTime(),
                        const SizedBox(height: AppTheme.xxl),
                        _buildSectionLabel('Quick presets'),
                        const SizedBox(height: AppTheme.md),
                        _buildPresetChips(),
                        const SizedBox(height: AppTheme.xl),
                        _buildSectionLabel('Custom duration'),
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
                color: AppTheme.surface.withOpacity(0.5),
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppTheme.onBackground,
                size: 16,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.md),
          const Text(
            'Set focus duration',
            style: TextStyle(
              color: AppTheme.onBackground,
              fontSize: 17,
              fontWeight: FontWeight.w600,
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
            shaderCallback: (bounds) => AppTheme.textGradient.createShader(bounds),
            child: Text(
              _formatDuration(_selectedSeconds),
              style: const TextStyle(
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
              color: AppTheme.onBackground2.withOpacity(0.7),
              fontSize: 15,
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
      style: const TextStyle(
        color: AppTheme.onBackground2,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
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
            trackHeight: 3,
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
                color: AppTheme.onBackground2.withOpacity(0.5),
                fontSize: 11,
              ),
            ),
            Text(
              '${_maxMinutes ~/ 60}h',
              style: TextStyle(
                color: AppTheme.onBackground2.withOpacity(0.5),
                fontSize: 11,
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
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D1B3E), Color(0xFF05061A)],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: AppTheme.primary.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.18),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: const Icon(
              Icons.timer_outlined,
              color: AppTheme.onBackground2,
              size: 22,
            ),
          ),
          const SizedBox(width: AppTheme.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Session breakdown',
                  style: TextStyle(
                    color: AppTheme.onBackground,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _buildBreakdownText(h, m, pomodoroCount),
                  style: const TextStyle(
                    color: AppTheme.onBackground2,
                    fontSize: 12,
                    height: 1.5,
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
          borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: () => widget.onConfirm(_selectedSeconds),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
            ),
          ),
          child: const Text(
            'Start session',
            style: TextStyle(
              color: AppTheme.onPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}