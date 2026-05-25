import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
          body: SafeArea(
            child: _buildBody(context, ref, state),
          ),
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
              backgroundColor: Colors.transparent, // transparent — bg shows through
              elevation: 0,
              title: Text(
                'Dashboard',
                style: GoogleFonts.googleSans(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
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
              child: DashboardSectionHeader(
                title: 'Tasks',
                showRefresh: true,
              ),
            ),

            // ── Tasks List — SliverList for large lists ────────────────────
            SliverPadding(
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  sliver: SliverToBoxAdapter(
    child: Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10), // Reduced bottom padding slightly
      decoration: BoxDecoration(
        gradient: AppTheme.surfaceGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 300, // Adjust this number based on how many sub-boxes you want visible at once
            child: ListView.builder(
              padding: EdgeInsets.zero, // Clears default list view padding
              shrinkWrap: false,         // No longer needed to shrink since height is explicit
              physics: const BouncingScrollPhysics(), // 2. Restores smooth scrolling mechanics inside the card
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
                separatorBuilder: (_, __) => const Divider(
                  height: 1,
                  color: AppTheme.dividerColor,
                ),
                itemBuilder: (context, i) => RecentActivityTile(
                  activity: analytics.recentActivities[i],
                  showDivider: false,
                ),
              ),
            ),

          ],
        ),
      ),
    );
  }
}