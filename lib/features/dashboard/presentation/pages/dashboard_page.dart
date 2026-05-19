import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nova/core/theme/app_theme.dart';
import 'package:nova/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:nova/features/dashboard/presentation/widgets/dashboard_header.dart';
import 'package:nova/features/dashboard/presentation/widgets/dashboard_section_header.dart';
import 'package:nova/features/dashboard/presentation/widgets/donut_progress_chart.dart';
import 'package:nova/features/dashboard/presentation/widgets/recent_activity_tile.dart';
import 'package:nova/features/dashboard/presentation/widgets/task_list_tile.dart';
import 'package:nova/features/dashboard/presentation/widgets/weekly_line_chart.dart';
import 'package:nova/shared/providers/global_providers.dart';
import 'package:google_fonts/google_fonts.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardProvider);
    final user = ref.watch(userProvider);
    return Scaffold(
      backgroundColor: AppTheme.bgGradEnd,
      body: SafeArea(
        child: state.when(
          loading: () => const Center(
            child: CircularProgressIndicator(),
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

              // ── App Bar ────────────────────────────────────────────────
              SliverAppBar(
                floating: true,
                snap: true,
                backgroundColor: AppTheme.bgGradEnd,
                elevation: 0,
                title: const Text(
                  'Dashboard',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
                
              ),        
              // ── Header (avatar + welcome + bell) ──────────────────────
                // Pinned so it stays visible while scrolling
                // Remove the entire SliverAppBar block and replace with:
SliverToBoxAdapter(
  child: Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: const DashboardHeader(),
  ),
),
              // ── Donut Chart (Task Progress) ────────────────────────────
              SliverToBoxAdapter(
                child: DonutProgressChart(key: const ValueKey('donut'), data: analytics),
              ),

              // ── Weekly Line Chart ──────────────────────────────────────
              SliverToBoxAdapter(
                child: WeeklyLineChart(points: analytics.weeklyProgress),
              ),

              // ── Tasks Section Header ───────────────────────────────────
              SliverToBoxAdapter(
                child: DashboardSectionHeader(
                  title: 'Tasks',
                  showRefresh: true,
                ),
              ),

              // ── Tasks List ─────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    gradient: AppTheme.surfaceGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: List.generate(
                        analytics.tasks.length,
                        (i) => TaskListTile(
                          task: analytics.tasks[i],
                          showDivider: i < analytics.tasks.length - 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── Recent Activity Section Header ─────────────────────────
              SliverToBoxAdapter(
                child: DashboardSectionHeader(
                  title: 'Recent Activity',
                  showRefresh: false,
                ),
              ),

              // ── Recent Activity List ───────────────────────────────────
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  decoration: BoxDecoration(
                    gradient: AppTheme.surfaceGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: List.generate(
                        analytics.recentActivities.length,
                        (i) => RecentActivityTile(
                          activity: analytics.recentActivities[i],
                          showDivider:
                              i < analytics.recentActivities.length - 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            ],
          ),
        ),
      ),
      ),
    );
  }
}// TODO Implement this library.