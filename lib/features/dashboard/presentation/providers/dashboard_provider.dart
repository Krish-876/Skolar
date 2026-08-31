import 'package:dotlottie_loader/dotlottie_loader.dart';
import 'package:flutter/widgets.dart' show SizedBox;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart' as lottie;
import '../../../../core/utils/usecase.dart';
import '../../data/datasources/dashboard_datasource.dart';
import '../../data/repository_impl/dashboard_repository_impl.dart';
import '../../domain/entities/dashboard_entity.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../../domain/usecases/dashboard_usecases.dart';

enum StreakViewMode { week, month }

/// Every visual state the expanded task section can be in — driven by the
/// on-page debug toggle so each one can be reviewed without waiting on real
/// async timing or engineering a real error/stale response.
enum DebugTaskSectionState {
  real,
  loading,
  error,
  stale,
  noTasksRemaining,
  noDataYet,
}

final _dashboardDataSourceProvider = Provider<DashboardDataSource>(
  (ref) => DashboardDummyDataSource(),
);

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => DashboardRepositoryImpl(ref.read(_dashboardDataSourceProvider)),
);

final _getProgressStatsProvider = Provider(
  (ref) => GetProgressStats(ref.read(dashboardRepositoryProvider)),
);
final _getDashboardPlanProvider = Provider(
  (ref) => GetDashboardPlan(ref.read(dashboardRepositoryProvider)),
);
final _toggleTaskCompletionProvider = Provider(
  (ref) => ToggleTaskCompletion(ref.read(dashboardRepositoryProvider)),
);
final _getDevelopmentAxesProvider = Provider(
  (ref) => GetDevelopmentAxes(ref.read(dashboardRepositoryProvider)),
);

final progressStatsProvider = FutureProvider<ProgressStats>((ref) async {
  final result = await ref.read(_getProgressStatsProvider)(const NoParams());
  return result.fold(
    (failure) => throw Exception(failure.message),
    (data) => data,
  );
});

final developmentAxesProvider = FutureProvider<List<DevelopmentAxis>>((
  ref,
) async {
  final result = await ref.read(_getDevelopmentAxesProvider)(const NoParams());
  return result.fold(
    (failure) => throw Exception(failure.message),
    (data) => data,
  );
});

/// Pre-decoded composition for the "no tasks remaining" empty-state
/// animation in the expanded progress card's task list. `DotLottieLoader`
/// only unzips the `.lottie` archive into raw animation bytes — the actual
/// `LottieComposition` (JSON parse) still happened lazily inside
/// `Lottie.memory` at the point the empty state first rendered, i.e. right
/// as the card's expand reveal needed it on-screen. Decoding it once here
/// and handing the widget a ready `LottieComposition` (see `_TodaysTasks` in
/// expandable_progress_card.dart) moves both async steps off the reveal's
/// critical frame. `DashboardPage.initState` reads this eagerly so the work
/// starts at page load, not on first expand.
final emptyTasksLottieProvider = FutureProvider<lottie.LottieComposition?>((
  ref,
) async {
  final loader = DotLottieLoader.fromAsset(
    'assets/animations/empty_tasks.lottie',
    frameBuilder: (context, dotLottie) => const SizedBox.shrink(),
  );
  try {
    final dotLottie = await loader.dotlottieLoader.load();
    final bytes = dotLottie.animations.values.single;
    return await lottie.LottieComposition.fromBytes(bytes);
  } catch (_) {
    return null;
  }
});

final streakViewModeProvider = StateProvider<StreakViewMode>(
  (ref) => StreakViewMode.week,
);

/// Whether the "All-Round Development" card's per-axis breakdown is expanded
/// (see `AllRoundDevelopmentCard`). Shared via a provider rather than local
/// widget state so `ExpandableProgressCard`, elsewhere in the tree, can
/// `ref.listen` to this toggle and re-measure its anchor across the
/// AnimatedSize resize it drives — the same reason `streakViewModeProvider`
/// above is a provider and not local state to the heatmap.
final developmentDetailsOpenProvider = StateProvider<bool>((ref) => false);

final debugTaskSectionStateProvider = StateProvider<DebugTaskSectionState>(
  (ref) => DebugTaskSectionState.real,
);

/// Bumped by `DashboardPage`'s pull-to-refresh on every reload — a plain
/// counter other widgets can `ref.listen` for, not data itself. The week
/// strip (`_WeekStrip` in streak_strip.dart) listens for this to page itself
/// back to the current week on refresh, regardless of which week the user
/// had swiped to.
final dashboardRefreshSignalProvider = StateProvider<int>((ref) => 0);

final dashboardPlanProvider =
    AsyncNotifierProvider<DashboardPlanNotifier, DashboardPlan>(
      DashboardPlanNotifier.new,
    );

class DashboardPlanNotifier extends AsyncNotifier<DashboardPlan> {
  @override
  Future<DashboardPlan> build() async {
    final result = await ref.read(_getDashboardPlanProvider)(const NoParams());
    return result.fold(
      (failure) => throw Exception(failure.message),
      (data) => data,
    );
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  Future<void> toggleTask(String taskId) async {
    final result = await ref.read(_toggleTaskCompletionProvider)(
      ToggleTaskParams(taskId),
    );
    state = result.fold(
      (failure) => AsyncError(Exception(failure.message), StackTrace.current),
      (plan) => AsyncData(plan),
    );
  }
}
