import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Skolar/shared/components/framed_avatar.dart';
import 'package:Skolar/shared/providers/global_providers.dart';

const Color _kBadgeBg = Color(0xFF1C1C1E);
const Color _kPillBg = Color(0xFF232326);
const Color _kTextSecondary = Colors.white60;

/// Top-of-screen "VS" style header: the current player's badge on the left,
/// their personal-best score badge on the right, and a centered countdown
/// pill beneath — a minimal, colorless restyle matching the reference UI.
class MathGameStatsBar extends ConsumerWidget {
  final int score;
  final int bestScore;
  final double remainingSeconds;
  final double totalSeconds;
  final VoidCallback onExit;

  const MathGameStatsBar({
    super.key,
    required this.score,
    required this.bestScore,
    required this.remainingSeconds,
    required this.totalSeconds,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: onExit,
                icon: const Icon(Icons.close_rounded, color: Colors.white60),
                tooltip: 'Exit Game',
                iconSize: 20,
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
              ),
              Expanded(
                child: _PlayerBadge(
                  name: user.name.isNotEmpty ? user.name : 'You',
                  score: score,
                  alignment: CrossAxisAlignment.start,
                  avatar:
                      (user.avatarData != null &&
                          user.avatarData!.trim().isNotEmpty)
                      ? FramedAvatar(
                          size: 40,
                          backgroundColor: _kBadgeBg,
                          svgString: user.avatarData!,
                        )
                      : _InitialAvatar(
                          initial: user.name.isNotEmpty
                              ? user.name[0].toUpperCase()
                              : 'Y',
                        ),
                ),
              ),
              Expanded(
                child: _PlayerBadge(
                  name: 'BEST',
                  score: bestScore,
                  alignment: CrossAxisAlignment.end,
                  avatar: const _IconAvatar(icon: Icons.emoji_events_outlined),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _TimerPill(remainingSeconds: remainingSeconds),
        ],
      ),
    );
  }
}

class _PlayerBadge extends StatelessWidget {
  final String name;
  final int score;
  final Widget avatar;
  final CrossAxisAlignment alignment;

  const _PlayerBadge({
    required this.name,
    required this.score,
    required this.avatar,
    required this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'GoogleSans',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        avatar,
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: _kPillBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$score',
            style: const TextStyle(
              fontFamily: 'GoogleSans',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _InitialAvatar extends StatelessWidget {
  final String initial;
  const _InitialAvatar({required this.initial});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: _kBadgeBg, shape: BoxShape.circle),
      child: Text(
        initial,
        style: const TextStyle(
          fontFamily: 'GoogleSans',
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _IconAvatar extends StatelessWidget {
  final IconData icon;
  const _IconAvatar({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: _kBadgeBg, shape: BoxShape.circle),
      child: Icon(icon, size: 18, color: Colors.white70),
    );
  }
}

class _TimerPill extends StatelessWidget {
  final double remainingSeconds;
  const _TimerPill({required this.remainingSeconds});

  @override
  Widget build(BuildContext context) {
    final totalSecs = remainingSeconds.ceil().clamp(0, 5999);
    final minutes = totalSecs ~/ 60;
    final secs = totalSecs % 60;
    final label = '$minutes:${secs.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: _kPillBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt_rounded, size: 16, color: _kTextSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'GoogleSans',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
