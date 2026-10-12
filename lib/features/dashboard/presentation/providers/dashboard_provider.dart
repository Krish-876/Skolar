import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/activity_log_service.dart';
import '../../../../core/services/activity_log_service_impl.dart';
import '../../../../core/utils/usecase.dart';
import '../../data/datasources/dashboard_datasource.dart';
import '../../data/datasources/dashboard_supabase_datasource.dart';
import '../../data/repository_impl/dashboard_repository_impl.dart';
import '../../domain/entities/dashboard_entity.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../../domain/usecases/dashboard_usecases.dart';

export '../../data/datasources/dashboard_datasource.dart'
    show DashboardDummyDataSource;

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

// ---------------------------------------------------------------------------
// Activity log service provider
// ---------------------------------------------------------------------------

/// Exposed so focus_timer_page.dart can call it after a session completes.
final activityLogServiceProvider = Provider<ActivityLogService>(
  (ref) => ActivityLogServiceImpl(Supabase.instance.client),
);

// ---------------------------------------------------------------------------
// Dashboard data providers
// ---------------------------------------------------------------------------

/// Switch this to DashboardDummyDataSource() to go back to dummy data.
/// Kept as a separate Provider so tests can override it with a
/// DashboardDummyDataSource without touching anything else.
final dashboardDataSourceProvider = Provider<DashboardDataSource>(
  (ref) => DashboardSupabaseDataSource(Supabase.instance.client),
);

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => DashboardRepositoryImpl(ref.read(dashboardDataSourceProvider)),
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
