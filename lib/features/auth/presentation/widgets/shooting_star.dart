// In space_background.dart, replace the _ShootingStar class
// with this version that uses a factory constructor for spawning:

import 'dart:math';

class _ShootingStar {
  double x;
  double y;
  double angle;
  double speed;
  double trailLength;
  double progress;
  bool active;

  _ShootingStar.inactive()
      : x = 0, y = 0, angle = 0, speed = 0,
        trailLength = 0, progress = 0, active = false;

  void spawn(Random rng) {
    x = rng.nextDouble() * 0.5;              // left half of screen
    y = rng.nextDouble() * 0.3;             // upper third
    angle = -0.38;                          // fixed diagonal (≈ -22°)
    speed = rng.nextDouble() * 0.12 + 0.10; // 0.10–0.22 per second
    trailLength = rng.nextDouble() * 0.08 + 0.12;
    progress = 0;
    active = true;
  }
}

// // And update _spawnShootingStar() in _SpaceBackgroundState:
// void _spawnShootingStar() {
//   for (final s in _shootPool) {
//     if (!s.active) {
//       s.spawn(_rng);
//       break;
//     }
//   }
// }

// // And update initState pool creation:
// _shootPool = List.generate(
//   _shootPoolSize,
//   (_) => _ShootingStar.inactive(),
// );