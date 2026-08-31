import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:Skolar/core/theme/app_theme.dart';
import 'package:Skolar/features/dashboard/domain/entities/dashboard_entity.dart';
import 'package:Skolar/features/dashboard/presentation/providers/dashboard_provider.dart';

/// Seven-block week strip that reshapes into a full calendar-month grid
/// (swipe sideways to change month). Both read completion counts from
/// [progressStatsProvider]'s rolling 30-day window — days outside that
/// window (e.g. a swiped-to earlier month) just render as empty. The view
/// mode is toggled by the 3-dot menu carried right here, alongside the strip
/// itself, via [streakViewModeProvider] — not up in the dashboard header.
class StreakStrip extends ConsumerWidget {
  const StreakStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(progressStatsProvider);
    final mode = ref.watch(streakViewModeProvider);

    return statsAsync.maybeWhen(
      data: (stats) => _StreakStripBody(
        mode: mode,
        dailyCompletions: stats.dailyCompletions,
      ),
      orElse: () => const SizedBox(height: 28),
    );
  }
}

Color _tint(int tasksCompleted) {
  if (tasksCompleted <= 0) return AppTheme.surface;
  const steps = [0.25, 0.45, 0.65, 0.85, 1.0];
  final alpha = steps[(tasksCompleted - 1).clamp(0, steps.length - 1)];
  return AppTheme.accent.withValues(alpha: alpha);
}

class _StreakStripBody extends StatelessWidget {
  final StreakViewMode mode;
  final List<DailyCompletion> dailyCompletions;

  const _StreakStripBody({required this.mode, required this.dailyCompletions});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The week/month view-mode toggle lives here, beside the heatmap
        // itself, rather than up in the dashboard header — it's this
        // widget's own control, not a page-level one. A label describing
        // the current view sits in the same row, at the same height as the
        // 3-dot menu, rather than floating unlabeled.
        Row(
          children: [
            Expanded(
              // Cross-fades instead of popping instantly between "Your
              // progress this week" and "Month summary" — matches the rest
              // of this transition, which is otherwise all smooth motion.
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                // Default `layoutBuilder` stacks outgoing/incoming children
                // centered — since "Month summary" is shorter than "Your
                // progress this week", that centered it within the wider
                // text's bounding box mid-fade instead of keeping it flush
                // against the left edge like every other label here.
                layoutBuilder: (currentChild, previousChildren) => Stack(
                  alignment: Alignment.centerLeft,
                  children: [...previousChildren, ?currentChild],
                ),
                child: Text(
                  mode == StreakViewMode.week
                      ? 'Your progress this week'
                      : 'Month summary',
                  key: ValueKey(mode),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'GoogleSans',
                    color: AppTheme.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const _StreakViewModeToggle(),
          ],
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            // Its height — not its width — is what changes between the week
            // strip (one row of blocks) and the much taller month grid
            // (a month-label row + 6 rows of blocks), so the size
            // transition animates on the vertical axis.
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SizeTransition(
                sizeFactor: animation,
                axis: Axis.vertical,
                alignment: Alignment.topCenter,
                child: child,
              ),
            ),
            child: mode == StreakViewMode.week
                ? _WeekStrip(
                    key: const ValueKey('week'),
                    days: dailyCompletions,
                  )
                : _MonthGrid(
                    key: const ValueKey('month'),
                    days: dailyCompletions,
                  ),
          ),
        ),
      ],
    );
  }
}

/// Switchable chip-like segmented toggle for [streakViewModeProvider] (week/month view)
/// consistent with the app's tactile pill design.
class _StreakViewModeToggle extends ConsumerWidget {
  const _StreakViewModeToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(streakViewModeProvider);
    final isWeek = mode == StreakViewMode.week;

    return Container(
      height: 28,
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: AppTheme.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: SizedBox(
        width: 116,
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              alignment: isWeek ? Alignment.centerLeft : Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: 0.5,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: _ModeChip(
                    label: 'Week',
                    active: isWeek,
                    onTap: () {
                      if (!isWeek) {
                        ref.read(streakViewModeProvider.notifier).state =
                            StreakViewMode.week;
                      }
                    },
                  ),
                ),
                Expanded(
                  child: _ModeChip(
                    label: 'Month',
                    active: !isWeek,
                    onTap: () {
                      if (isWeek) {
                        ref.read(streakViewModeProvider.notifier).state =
                            StreakViewMode.month;
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ModeChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Center(
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          style: TextStyle(
            fontFamily: 'GoogleSans',
            fontSize: 11,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? AppTheme.onPrimary : AppTheme.textMuted,
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

/// Row of day pills (weekday letter + date number), today highlighted — a
/// calendar-strip look, still tinted by that day's completion count (see
/// [_tint]) so it keeps doubling as a mini streak heatmap rather than
/// becoming a plain, data-free date picker.
///
/// Swipe sideways to move between calendar weeks (Sunday-start, matching the
/// month grid's own week-start convention below) — the same `PageView`
/// technique `_MonthGrid` already uses, rather than a single fixed "last 7
/// days" strip with no navigation. Days outside [days]' rolling window (a
/// swiped-to earlier/later week) just render as empty, same as the month
/// grid does for its own out-of-window days.
class _WeekStrip extends ConsumerStatefulWidget {
  final List<DailyCompletion> days;
  const _WeekStrip({super.key, required this.days});

  @override
  ConsumerState<_WeekStrip> createState() => _WeekStripState();
}

class _WeekStripState extends ConsumerState<_WeekStrip> {
  // Arbitrary large starting index so the user can swipe backwards for
  // "years" before hitting page 0 — pages are addressed relative to this,
  // not absolute, so there's no meaningful upper bound either. Same
  // convention as `_MonthGridState`.
  static const _initialPage = 1200;
  static const _pillHeight = 62.0;

  late final DateTime _anchorWeekStart = _sundayOnOrBefore(DateTime.now());
  late final PageController _pageController = PageController(
    initialPage: _initialPage,
  );
  int _currentPage = _initialPage;

  static DateTime _sundayOnOrBefore(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    // DateTime.weekday is 1=Mon..7=Sun; rebase to 0=Sun..6=Sat, matching the
    // month grid's own rebasing, so both views agree on where a week starts.
    return d.subtract(Duration(days: d.weekday % 7));
  }

  DateTime _weekStartForPage(int page) =>
      _anchorWeekStart.add(Duration(days: (page - _initialPage) * 7));

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Pull-to-refresh (see `DashboardPage._onRefresh`) bumps this so the
    // strip pages itself back to the current week on reload, regardless of
    // which week the user had swiped to.
    ref.listen<int>(dashboardRefreshSignalProvider, (previous, next) {
      if (previous == null || previous == next || !_pageController.hasClients) {
        return;
      }
      _pageController.animateToPage(
        _initialPage,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    });

    final byDate = {
      for (final d in widget.days)
        DateTime(d.date.year, d.date.month, d.date.day): d.tasksCompleted,
    };
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    // On the current week, show today's actual date (as always). Paged away
    // to a different week, show that week's own start date instead — so
    // scrolling far enough to cross into a new month updates the month
    // shown here too, instead of this staying frozen on "today" regardless
    // of which week is actually on screen.
    final headerDate = _currentPage == _initialPage
        ? today
        : _weekStartForPage(_currentPage);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            DateFormat('d MMMM').format(headerDate),
            style: TextStyle(
              fontFamily: 'GoogleSans',
              color: AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: _pillHeight,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (page) => setState(() => _currentPage = page),
            itemBuilder: (context, page) {
              final weekStart = _weekStartForPage(page);
              return Row(
                children: List.generate(7, (i) {
                  final date = weekStart.add(Duration(days: i));
                  final isToday = date == todayDate;
                  final tasksCompleted = byDate[date] ?? 0;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isToday
                              ? AppTheme.accent
                              : _tint(tasksCompleted),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        // This pill sits in a fixed-height (`_pillHeight`) row —
                        // at any system text-scale setting above 1.0x the two
                        // lines of text no longer fit that fixed budget,
                        // overflowing the bottom (confirmed: a genuine 6px
                        // RenderFlex overflow at 1.3x scale). Capping just this
                        // compact pill's own scaling keeps it inside its box
                        // while a "smaller text" setting can still shrink it,
                        // same tradeoff already made for `_StatBadge` elsewhere
                        // on this dashboard.
                        child: MediaQuery.withClampedTextScaling(
                          maxScaleFactor: 1.0,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                DateFormat('E').format(date).substring(0, 1),
                                style: TextStyle(
                                  fontFamily: 'GoogleSans',
                                  color: isToday
                                      ? AppTheme.onPrimary
                                      : AppTheme.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${date.day}',
                                style: TextStyle(
                                  fontFamily: 'GoogleSans',
                                  color: isToday
                                      ? AppTheme.onPrimary
                                      : AppTheme.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// One calendar month's heatmap — hand-rolled instead of using
/// `flutter_heatmap_calendar` (which the week-column-margin-solving approach
/// used previously): that package always draws its own week-day/month label
/// rows and only exposes spacing via per-block margin, so it could never
/// produce a true edge-to-edge grid with zero gaps between blocks, nor show
/// a single specific month without its own multi-month label row.
///
/// Shows exactly the days of one calendar month (not a rolling 30-day
/// window) — swipe sideways to move between months, the same way the rest
/// of the OS treats a horizontal calendar strip. There are no prev/next
/// buttons; the grid itself is the scroll surface.
class _MonthGrid extends ConsumerStatefulWidget {
  final List<DailyCompletion> days;
  const _MonthGrid({super.key, required this.days});

  @override
  ConsumerState<_MonthGrid> createState() => _MonthGridState();
}

class _MonthGridState extends ConsumerState<_MonthGrid> {
  // Every month's grid always reserves 6 rows regardless of how many it
  // actually needs (a month never spans more than 6 — 31 days plus at most
  // 6 leading blanks is 37 cells, i.e. always ≤ 42) so every page in the
  // PageView below has the same fixed height: PageView lays every page out
  // at the same extent, it doesn't size itself to each page's own content.
  static const _rowCount = 6;
  // Arbitrary large starting index so the user can swipe backwards for
  // "years" before hitting page 0 — pages are addressed relative to this,
  // not absolute, so there's no meaningful upper bound either.
  static const _initialPage = 1200;

  late final DateTime _anchorMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );
  late final PageController _pageController = PageController(
    initialPage: _initialPage,
  );
  int _currentPage = _initialPage;

  DateTime _monthForPage(int page) =>
      DateTime(_anchorMonth.year, _anchorMonth.month + (page - _initialPage));

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Same pull-to-refresh behavior as `_WeekStripState` — pages back to
    // the current month on reload, regardless of which month the user had
    // swiped to.
    ref.listen<int>(dashboardRefreshSignalProvider, (previous, next) {
      if (previous == null || previous == next || !_pageController.hasClients) {
        return;
      }
      _pageController.animateToPage(
        _initialPage,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    });

    final byDate = {
      for (final d in widget.days)
        DateTime(d.date.year, d.date.month, d.date.day): d.tasksCompleted,
    };
    final viewedMonth = _monthForPage(_currentPage);
    final today = DateTime.now();
    // Today's date only means something on the page actually showing the
    // current month — a swiped-to month has no "today" of its own, so that
    // page just falls back to the plain month/year label.
    final isCurrentMonth =
        viewedMonth.year == today.year && viewedMonth.month == today.month;
    final headerLabel = isCurrentMonth
        ? DateFormat('d MMMM y').format(today)
        : DateFormat('MMMM y').format(viewedMonth);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Center(
            child: Text(
              headerLabel,
              style: TextStyle(
                fontFamily: 'GoogleSans',
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ),
        // LayoutBuilder rather than MediaQuery for the block size: this sits
        // inside the header's own horizontal padding, so sizing off the raw
        // screen width (as a previous approach did) overflows past that
        // padding by exactly the padding amount. Using the constraints this
        // widget is actually given fills all the width it really has, with
        // no gaps between blocks and no gaps between rows.
        LayoutBuilder(
          builder: (context, constraints) {
            final blockSize = (constraints.maxWidth / 7).floorToDouble();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // One header row of weekday letters (Sun-start, matching the
                // grid below) instead of repeating the letter inside every
                // cell — Jan 1 2023 is a fixed, known Sunday, used purely as
                // an anchor to read locale-correct weekday initials off of.
                Row(
                  children: List.generate(7, (i) {
                    final label = DateFormat(
                      'E',
                    ).format(DateTime(2023, 1, 1 + i)).substring(0, 1);
                    return SizedBox(
                      width: blockSize,
                      child: Center(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontFamily: 'GoogleSans',
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: blockSize * _rowCount,
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (page) =>
                        setState(() => _currentPage = page),
                    itemBuilder: (context, page) {
                      final month = _monthForPage(page);
                      final daysInMonth = DateUtils.getDaysInMonth(
                        month.year,
                        month.month,
                      );
                      final firstDay = DateTime(month.year, month.month, 1);
                      // DateTime.weekday is 1=Mon..7=Sun; rebase to 0=Sun..6=Sat
                      // so the grid starts its first row on Sunday, matching
                      // the week strip above it.
                      final leadingBlanks = firstDay.weekday % 7;
                      final trailingBlanks =
                          _rowCount * 7 - leadingBlanks - daysInMonth;
                      return Wrap(
                        spacing: 0,
                        runSpacing: 0,
                        children: [
                          for (var i = 0; i < leadingBlanks; i++)
                            SizedBox(width: blockSize, height: blockSize),
                          for (var day = 1; day <= daysInMonth; day++)
                            _HeatBlock(
                              size: blockSize,
                              date: DateTime(month.year, month.month, day),
                              tasksCompleted:
                                  byDate[DateTime(
                                    month.year,
                                    month.month,
                                    day,
                                  )] ??
                                  0,
                              isToday:
                                  month.year == today.year &&
                                  month.month == today.month &&
                                  day == today.day,
                            ),
                          for (var i = 0; i < trailingBlanks; i++)
                            SizedBox(width: blockSize, height: blockSize),
                        ],
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _HeatBlock extends StatelessWidget {
  final double size;
  final DateTime date;
  final int tasksCompleted;
  final bool isToday;
  const _HeatBlock({
    required this.size,
    required this.date,
    required this.tasksCompleted,
    this.isToday = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isToday ? AppTheme.accent : _tint(tasksCompleted),
        // Proportional to the block's own size (not a fixed theme token)
        // since `size` varies with screen width — a fixed px radius reads as
        // barely-there on a wide screen's larger blocks and too round on a
        // narrow screen's smaller ones. Dialed down from 0.3 (too round).
        borderRadius: BorderRadius.circular(size * 0.15),
        // Blocks sit edge-to-edge with zero spacing, so without a border
        // same-tint neighbors (e.g. two empty days) visually fuse into one
        // shape — a thin border gives every block a defined edge regardless
        // of its neighbors' tint.
        border: Border.all(color: AppTheme.white.withValues(alpha: 0.08)),
      ),
      // The date number — the weekday letter now lives once, in the header
      // row above the whole grid (see `_MonthGridState.build()`), rather
      // than repeated inside every cell. Sized off the block itself (like
      // the border radius above) so it scales with screen width instead of
      // overflowing a small block or looking tiny in a large one.
      child: Text(
        '${date.day}',
        style: TextStyle(
          fontFamily: 'GoogleSans',
          color: isToday ? AppTheme.onPrimary : AppTheme.textPrimary,
          fontSize: (size * 0.32).clamp(9.0, 13.0),
          fontWeight: isToday ? FontWeight.w700 : FontWeight.w600,
        ),
      ),
    );
  }
}
