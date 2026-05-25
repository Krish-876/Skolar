class FocusPreset {
  final String label;
  final int seconds;

  const FocusPreset({required this.label, required this.seconds});

  static const List<FocusPreset> defaults = [
    FocusPreset(label: 'Pomodoro', seconds: 25 * 60),
    FocusPreset(label: '45 min',   seconds: 45 * 60),
    FocusPreset(label: '1 hr',     seconds: 60 * 60),
  ];
}