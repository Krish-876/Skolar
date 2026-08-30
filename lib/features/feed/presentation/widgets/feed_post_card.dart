import 'package:Skolar/features/mock_tests/presentation/providers/mock_tests_provider.dart';
import 'package:Skolar/shared/models/exam_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Skolar/core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import '../../domain/entities/feed_post_entity.dart';
import '../providers/feed_provider.dart';
import 'feed_colors.dart';

class FeedPostCard extends ConsumerStatefulWidget {
  final FeedPostEntity post;
  final int index;

  const FeedPostCard({super.key, required this.post, required this.index});

  @override
  ConsumerState<FeedPostCard> createState() => _FeedPostCardState();
}

class _FeedPostCardState extends ConsumerState<FeedPostCard>
    with TickerProviderStateMixin {
  late final AnimationController _upvoteController;
  late final Animation<double> _upvoteScale;
  late final AnimationController _downvoteController;
  late final Animation<double> _downvoteScale;

  @override
  void initState() {
    super.initState();

    _upvoteController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _upvoteScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.55), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.55, end: 0.88), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.88, end: 1.0), weight: 35),
    ]).animate(_upvoteController);

    _downvoteController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _downvoteScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.55), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.55, end: 0.88), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.88, end: 1.0), weight: 35),
    ]).animate(_downvoteController);
  }

  @override
  void dispose() {
    _upvoteController.dispose();
    _downvoteController.dispose();
    super.dispose();
  }

  void _handleUpvote() {
    _upvoteController.forward(from: 0);
    ref.read(feedProvider.notifier).toggleUpvote(widget.post.id);
  }

  void _handleDownvote() {
    _downvoteController.forward(from: 0);
    ref.read(feedProvider.notifier).toggleDownvote(widget.post.id);
  }

  void _handleAttempt() async {
    final mode = widget.post.examType == ExamType.compre
        ? ExamMode.mcqBlitz
        : ExamMode.writtenPractice;

    await ref
        .read(mockTestProvider.notifier)
        .loadExistingTest(questionIds: widget.post.questionIds, mode: mode);

    if (!mounted) return;
    context.push('/mock-tests');
  }

  @override
  Widget build(BuildContext context) {
    // .select ensures only THIS card rebuilds when its own vote state changes
    final upvoted = ref.watch(
      upvotedPostsProvider.select((s) => s.contains(widget.post.id)),
    );
    final downvoted = ref.watch(
      downvotedPostsProvider.select((s) => s.contains(widget.post.id)),
    );
    final currentPost = ref
        .watch(feedProvider)
        .maybeWhen(
          data: (posts) => posts.firstWhere(
            (p) => p.id == widget.post.id,
            orElse: () => widget.post,
          ),
          orElse: () => widget.post,
        );
    final upvoteCount = currentPost.upvotes;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: AppTheme.onboardingButtonBorder, width: 1),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTop(post: widget.post),
          const SizedBox(height: 12),
          _CardTitle(title: widget.post.title),
          const SizedBox(height: 12),
          _TagRow(tags: widget.post.tags, subject: widget.post.subject),
          const SizedBox(height: 14),
          _CardFooter(
            post: widget.post,
            upvoted: upvoted,
            downvoted: downvoted,
            upvoteCount: upvoteCount,
            upvoteScale: _upvoteScale,
            downvoteScale: _downvoteScale,
            onUpvote: _handleUpvote,
            onDownvote: _handleDownvote,
            onAttempt: _handleAttempt,
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _CardTop extends StatelessWidget {
  final FeedPostEntity post;
  const _CardTop({required this.post});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Avatar(initials: post.authorInitials),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                post.authorName,
                style: const TextStyle(
                  fontFamily: 'GoogleSans',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.onBackground,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                '${post.authorYear} · ${post.authorBranch}',
                style: const TextStyle(
                  fontFamily: 'GoogleSans',
                  fontSize: 11,
                  color: AppTheme.onBackground2,
                ),
              ),
            ],
          ),
        ),
        _DifficultyIndicator(difficulty: post.difficulty),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  final String initials;
  const _Avatar({required this.initials});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: AppTheme.accentPurple.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: Border.all(
          color: AppTheme.accentPurple.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          fontFamily: 'GoogleSans',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppTheme.accentPurple,
        ),
      ),
    );
  }
}

class _DifficultyIndicator extends StatelessWidget {
  final String difficulty;
  const _DifficultyIndicator({required this.difficulty});

  String get _label {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return 'Easy';
      case 'hard':
        return 'Hard';
      default:
        return 'Medium';
    }
  }

  @override
  Widget build(BuildContext context) {
    final dotColor = FeedColors.diffDot(difficulty);
    final textColor = FeedColors.diffText(difficulty);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
      decoration: BoxDecoration(
        color: dotColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: dotColor.withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            _label,
            style: TextStyle(
              fontFamily: 'GoogleSans',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  final String title;
  const _CardTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: 'GoogleSans',
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppTheme.onBackground,
        height: 1.4,
      ),
    );
  }
}

class _TagRow extends StatelessWidget {
  final List<String> tags;
  final String subject;
  const _TagRow({required this.tags, required this.subject});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: tags.map((tag) {
        final isSubject = tag == subject;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
          decoration: BoxDecoration(
            color: isSubject
                ? AppTheme.accentPurple.withValues(alpha: 0.15)
                : AppTheme.surfaceLight,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: isSubject
                  ? AppTheme.accentPurple.withValues(alpha: 0.5)
                  : AppTheme.onboardingButtonBorder,
              width: 0.8,
            ),
          ),
          child: Text(
            tag,
            style: TextStyle(
              fontFamily: 'GoogleSans',
              fontSize: 11,
              fontWeight: isSubject ? FontWeight.w600 : FontWeight.w500,
              color: isSubject ? AppTheme.accentPurple : AppTheme.onBackground2,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _CardFooter extends StatelessWidget {
  final FeedPostEntity post;
  final bool upvoted;
  final bool downvoted;
  final int upvoteCount;
  final Animation<double> upvoteScale;
  final Animation<double> downvoteScale;
  final VoidCallback onUpvote;
  final VoidCallback onDownvote;
  final VoidCallback onAttempt;

  const _CardFooter({
    required this.post,
    required this.upvoted,
    required this.downvoted,
    required this.upvoteCount,
    required this.upvoteScale,
    required this.downvoteScale,
    required this.onUpvote,
    required this.onDownvote,
    required this.onAttempt,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Upvote
        ScaleTransition(
          scale: upvoteScale,
          child: GestureDetector(
            onTap: onUpvote,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: upvoted
                    ? FeedColors.upvoteOn.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.arrow_upward_rounded,
                size: 20,
                color: upvoted ? FeedColors.upvoteOn : AppTheme.onBackground2,
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$upvoteCount',
          style: TextStyle(
            fontFamily: 'GoogleSans',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: upvoted
                ? FeedColors.upvoteOn
                : downvoted
                ? FeedColors.downvoteOn
                : AppTheme.onBackground2,
          ),
        ),
        const SizedBox(width: 4),
        // Downvote
        ScaleTransition(
          scale: downvoteScale,
          child: GestureDetector(
            onTap: onDownvote,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: downvoted
                    ? FeedColors.downvoteOn.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.arrow_downward_rounded,
                size: 20,
                color: downvoted
                    ? FeedColors.downvoteOn
                    : AppTheme.onBackground2,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Attempts
        const Icon(
          Icons.group_outlined,
          size: 14,
          color: AppTheme.onBackground2,
        ),
        const SizedBox(width: 4),
        Text(
          '${post.attempts}',
          style: const TextStyle(
            fontFamily: 'GoogleSans',
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppTheme.onBackground2,
          ),
        ),
        const Spacer(),
        // Attempt Button
        _MiniAttemptButton(onTap: onAttempt),
      ],
    );
  }
}

class _MiniAttemptButton extends StatefulWidget {
  final VoidCallback onTap;
  const _MiniAttemptButton({required this.onTap});

  @override
  State<_MiniAttemptButton> createState() => _MiniAttemptButtonState();
}

class _MiniAttemptButtonState extends State<_MiniAttemptButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        transform: _pressed
            ? Matrix4.translationValues(0, 2, 0)
            : Matrix4.identity(),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: AppTheme.accentPurple,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          boxShadow: _pressed
              ? []
              : const [
                  BoxShadow(
                    color: AppTheme.accentPurpleDark,
                    blurRadius: 0,
                    offset: Offset(0, 2),
                  ),
                ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_arrow_rounded, color: AppTheme.onPrimary, size: 15),
            SizedBox(width: 3),
            Text(
              'Attempt',
              style: TextStyle(
                fontFamily: 'GoogleSans',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
