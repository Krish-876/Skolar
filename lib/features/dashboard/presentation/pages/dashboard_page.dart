import 'package:Skolar/core/routing/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:Skolar/core/theme/app_theme.dart';
import 'package:Skolar/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:Skolar/features/dashboard/presentation/widgets/animated_mesh_bg.dart';
import 'package:Skolar/features/dashboard/presentation/widgets/dashboard_header.dart';
import 'package:Skolar/features/dashboard/presentation/widgets/dashboard_section_header.dart';
import 'package:Skolar/features/dashboard/presentation/widgets/donut_progress_chart.dart';
import 'package:Skolar/features/dashboard/presentation/widgets/recent_activity_tile.dart';
import 'package:Skolar/features/dashboard/presentation/widgets/task_list_tile.dart';
import 'package:Skolar/features/dashboard/presentation/widgets/weekly_line_chart.dart';
// ignore: unused_import
import 'package:Skolar/shared/providers/global_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardProvider);

    return Stack(
      children: [
        // ── Animated neon background — isolated in its own render layer ──────
        const AnimatedMeshBackground(),

        // ── Scaffold is transparent so the background shows through ──────────
        Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(child: _buildBody(context, ref, state)),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, AsyncValue state) {
    return state.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppTheme.accent),
      ),
      error: (error, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppTheme.error, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Failed to load dashboard',
              style: TextStyle(color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => ref.invalidate(dashboardProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (analytics) => RefreshIndicator(
        color: AppTheme.accent,
        backgroundColor: AppTheme.surface,
        onRefresh: () => ref.read(dashboardProvider.notifier).refresh(),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── App Bar ────────────────────────────────────────────────────
            SliverAppBar(
              floating: true,
              snap: true,
              backgroundColor:
                  Colors.transparent, // transparent — bg shows through
              elevation: 0,
              title: _DevMenuTrigger(
                child: Text(
                  'Dashboard',
                  style: GoogleFonts.googleSans(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
              ),
            ),

            // ── Header (avatar + welcome + bell) ──────────────────────────
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 10.0),
                child: DashboardHeader(),
              ),
            ),

            // ── Donut Chart ────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: DonutProgressChart(
                key: const ValueKey('donut'),
                data: analytics,
              ),
            ),

            // ── Weekly Line Chart ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: WeeklyLineChart(points: analytics.weeklyProgress),
            ),

            // ── Tasks Section Header ───────────────────────────────────────
            SliverToBoxAdapter(
              child: DashboardSectionHeader(title: 'Tasks', showRefresh: true),
            ),

            // ── Tasks List — SliverList for large lists ────────────────────
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              sliver: SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    20,
                    20,
                    10,
                  ), // Reduced bottom padding slightly
                  decoration: BoxDecoration(
                    gradient: AppTheme.surfaceGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height:
                            300, // Adjust this number based on how many sub-boxes you want visible at once
                        child: ListView.builder(
                          padding: EdgeInsets
                              .zero, // Clears default list view padding
                          shrinkWrap:
                              false, // No longer needed to shrink since height is explicit
                          physics:
                              const BouncingScrollPhysics(), // 2. Restores smooth scrolling mechanics inside the card
                          itemCount: analytics.tasks.length,
                          itemBuilder: (context, i) => TaskListTile(
                            task: analytics.tasks[i],
                            showDivider: false,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Recent Activity Section Header ─────────────────────────────
            SliverToBoxAdapter(
              child: DashboardSectionHeader(
                title: 'Recent Activity',
                showRefresh: false,
              ),
            ),

            // ── Recent Activity List ───────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverList.separated(
                itemCount: analytics.recentActivities.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, color: AppTheme.dividerColor),
                itemBuilder: (context, i) => RecentActivityTile(
                  activity: analytics.recentActivities[i],
                  showDivider: false,
                ),
              ),
            ),

            // ── Dev Navigation ─────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Dev Nav',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _DevButton(
                          'Mock Tests',
                          () => context.go(AppRoutes.mockTests),
                        ),
                        _DevButton('Feed', () => context.go(AppRoutes.feed)),
                        _DevButton(
                          'Focus',
                          () => context.go(AppRoutes.focusSession),
                        ),
                        _DevButton(
                          'Exam Predict',
                          () => context.go(AppRoutes.examPrediction),
                        ),
                        _DevButton(
                          'Profile',
                          () => context.go(AppRoutes.profile),
                        ),
                        _DevButton(
                          'PYQ Upload',
                          () => context.go(AppRoutes.pyqUpload),
                        ),
                        _DevButton(
                          'Colleges',
                          () => context.go(AppRoutes.colleges),
                        ),
                        _DevButton(
                          'Onboarding',
                          () => context.go(AppRoutes.onboarding),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: () async {
                    await Supabase.instance.client.auth.signOut();
                    context.go(AppRoutes.auth);
                  },
                  child: const Text('Sign Out'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// This should be at the very bottom of the file, outside everything else
class _DevButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _DevButton(this.label, this.onTap);

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.textPrimary,
        side: const BorderSide(color: AppTheme.accent),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}

class _DevMenuTrigger extends StatefulWidget {
  final Widget child;
  const _DevMenuTrigger({required this.child});

  @override
  State<_DevMenuTrigger> createState() => _DevMenuTriggerState();
}

class _DevMenuTriggerState extends State<_DevMenuTrigger> {
  int _tapCount = 0;
  DateTime? _lastTap;

  void _handleTap() {
    final now = DateTime.now();
    if (_lastTap != null &&
        now.difference(_lastTap!) > const Duration(milliseconds: 500)) {
      _tapCount = 0;
    }
    _tapCount++;
    _lastTap = now;

    if (_tapCount >= 3) {
      _tapCount = 0;
      context.push('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: _handleTap, child: widget.child);
  }
}
