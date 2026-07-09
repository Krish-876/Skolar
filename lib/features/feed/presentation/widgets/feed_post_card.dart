import 'package:Skolar/features/mock_tests/presentation/providers/mock_tests_provider.dart';
import 'package:Skolar/shared/models/exam_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Skolar/core/theme/app_theme.dart';
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

    final state = ref.read(mockTestProvider);
    print('hasQuestions: ${state.hasQuestions}');
    print('openQuestions: ${state.openQuestions.length}');
    print('isLoading: ${state.isLoading}');
    print('error: ${state.error}');
    print('questionIds passed: ${widget.post.questionIds}');

    if (!mounted) return;
    Navigator.pushNamed(context, '/mock-tests');
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
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.dividerColor, width: 0.25),
      ),
      padding: const EdgeInsets.fromLTRB(13, 13, 13, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTop(post: widget.post),
          const SizedBox(height: 7),
          _CardTitle(title: widget.post.title),
          const SizedBox(height: 8),
          _TagRow(tags: widget.post.tags, subject: widget.post.subject),
          const SizedBox(height: 10),
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
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                post.authorName,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: FeedColors.textSecondary,
                  fontFamily: 'DM Sans',
                ),
              ),
              Text(
                '${post.authorYear} · ${post.authorBranch}',
                style: const TextStyle(
                  fontSize: 10,
                  color: FeedColors.textHint,
                  fontFamily: 'DM Sans',
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
      width: 26,
      height: 26,
      decoration: const BoxDecoration(
        color: Color(0xFF1E1F2A),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: FeedColors.purple,
          fontFamily: 'DM Sans',
        ),
      ),
    );
  }
}

class _DifficultyIndicator extends StatelessWidget {
  final String difficulty;
  const _DifficultyIndicator({required this.difficulty});

  String get _label {
    switch (difficulty) {
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: FeedColors.diffDot(difficulty),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          _label,
          style: TextStyle(
            fontSize: 11,
            color: FeedColors.diffText(difficulty),
            fontFamily: 'DM Sans',
          ),
        ),
      ],
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
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: FeedColors.textPrimary,
        height: 1.45,
        fontFamily: 'DM Sans',
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
      spacing: 5,
      runSpacing: 5,
      children: tags.map((tag) {
        final isSubject = tag == subject;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: isSubject ? FeedColors.tagSubjBg : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSubject ? FeedColors.borderSubj : FeedColors.borderTag,
              width: 0.5,
            ),
          ),
          child: Text(
            tag,
            style: TextStyle(
              fontSize: 10,
              color: isSubject ? FeedColors.tagSubjText : FeedColors.tagText,
              fontFamily: 'DM Sans',
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
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.arrow_upward_rounded,
                size: 26,
                color: upvoted ? FeedColors.upvoteOn : FeedColors.textMuted,
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$upvoteCount',
          style: TextStyle(
            fontSize: 12,
            color: upvoted
                ? FeedColors.upvoteOn
                : downvoted
                ? FeedColors.downvoteOn
                : FeedColors.textMuted,
            fontFamily: 'DM Sans',
          ),
        ),
        const SizedBox(width: 4),
        // Downvote
        ScaleTransition(
          scale: downvoteScale,
          child: GestureDetector(
            onTap: onDownvote,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.arrow_downward_rounded,
                size: 26,
                color: downvoted ? FeedColors.downvoteOn : FeedColors.textMuted,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Attempts
        const Icon(Icons.group_outlined, size: 13, color: FeedColors.textHint),
        const SizedBox(width: 4),
        Text(
          '${post.attempts} attempted',
          style: const TextStyle(
            fontSize: 11,
            color: FeedColors.textHint,
            fontFamily: 'DM Sans',
          ),
        ),
        const Spacer(),
        // Attempt button
        GestureDetector(
          onTap: onAttempt,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: FeedColors.attemptBorder, width: 0.5),
            ),
            child: const Text(
              'Attempt',
              style: TextStyle(
                fontSize: 11,
                color: FeedColors.attemptText,
                fontFamily: 'DM Sans',
              ),
            ),
          ),
        ),
      ],
    );
  }
}
