import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:Skolar/core/routing/app_routes.dart';
import 'package:Skolar/features/profile/presentation/providers/profile_provider.dart';
import 'package:Skolar/shared/models/user_model.dart';
import 'package:Skolar/shared/providers/global_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _kBg = Color(0xFF16161A);
const _kSurface = Color(0xFF1C1C1E);
const _kPrimary = Color(0xFF8C38E5);

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  void _showSignOutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Sign Out',
          style: GoogleFonts.googleSans(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to sign out of your account?',
          style: GoogleFonts.googleSans(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.googleSans(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) context.go(AppRoutes.auth);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFCF6679),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Sign Out',
              style: GoogleFonts.googleSans(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    final detailsAsync = ref.watch(profileDetailsProvider);

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'My Profile',
          style: GoogleFonts.googleSans(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 0.3,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white70),
            tooltip: 'Sign Out',
            onPressed: () => _showSignOutDialog(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: _kPrimary,
        backgroundColor: _kSurface,
        onRefresh: () async {
          await ref.read(userProvider.notifier).refresh();
          ref.invalidate(profileDetailsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            children: [
              // 1. Identity & Avatar Header
              _ProfileSectionAnim(index: 0, child: _UserHeaderCard(user: user)),
              const SizedBox(height: 16),

              // 2. Academic Setup Card
              _ProfileSectionAnim(index: 1, child: _AcademicCard(user: user)),
              const SizedBox(height: 16),

              // 3. Study Capacity & Prep Style Card
              _ProfileSectionAnim(
                index: 2,
                child: detailsAsync.when(
                  data: (details) => _StrategyCard(
                    user: user,
                    endgame: details.endgame,
                    prepStyle: details.prepStyle,
                  ),
                  loading: () => const _LoadingCard(height: 160),
                  error: (_, _) => _StrategyCard(user: user),
                ),
              ),
              const SizedBox(height: 16),

              // 4. Career Interests Card
              _ProfileSectionAnim(
                index: 3,
                child: detailsAsync.when(
                  data: (details) =>
                      _InterestsCard(interests: details.careerInterests),
                  loading: () => const _LoadingCard(height: 120),
                  error: (_, _) => const _InterestsCard(interests: []),
                ),
              ),
              const SizedBox(height: 16),

              // 5. Account & Quick Actions
              _ProfileSectionAnim(
                index: 4,
                child: _AccountActionsCard(
                  user: user,
                  onSignOut: () => _showSignOutDialog(context),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Staggered Entrance Animation Wrapper
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileSectionAnim extends StatelessWidget {
  final int index;
  final Widget child;

  const _ProfileSectionAnim({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 360 + (index * 70)),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - v)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Loading Placeholder Card
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingCard extends StatelessWidget {
  final double height;
  const _LoadingCard({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2, color: _kPrimary),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. User Header Card
// ─────────────────────────────────────────────────────────────────────────────

class _UserHeaderCard extends StatelessWidget {
  final UserModel user;

  const _UserHeaderCard({required this.user});

  String _formatCampus(String college) {
    final lc = college.toLowerCase();
    if (lc.contains('hyderabad') || lc == 'bphc') return 'Hyderabad Campus';
    if (lc.contains('goa') || lc == 'bpgc') return 'Goa Campus';
    return 'Pilani Campus';
  }

  @override
  Widget build(BuildContext context) {
    final campus = _formatCampus(user.college);
    final initial = user.name.isNotEmpty ? user.name[0].toUpperCase() : 'S';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar circle
          Container(
            width: 72,
            height: 72,
            clipBehavior: Clip.antiAlias,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFF2F2F5),
            ),
            alignment: Alignment.center,
            child:
                (user.avatarData != null && user.avatarData!.trim().isNotEmpty)
                ? SvgPicture.string(
                    user.avatarData!,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                  )
                : Text(
                    initial,
                    style: GoogleFonts.googleSans(
                      color: _kPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        user.name,
                        style: GoogleFonts.googleSans(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _kPrimary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _kPrimary.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        user.plan.toUpperCase(),
                        style: GoogleFonts.googleSans(
                          color: const Color(0xFFD4A5FF),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
                if (user.rollNumber.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    user.rollNumber,
                    style: GoogleFonts.googleSans(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      color: _kPrimary,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      campus,
                      style: GoogleFonts.googleSans(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. Academic Card
// ─────────────────────────────────────────────────────────────────────────────

class _AcademicCard extends StatelessWidget {
  final UserModel user;

  const _AcademicCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.school_rounded, color: _kPrimary, size: 20),
              const SizedBox(width: 10),
              Text(
                'Academic Details',
                style: GoogleFonts.googleSans(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _InfoRow(
            icon: Icons.account_balance_rounded,
            label: 'Branch',
            value: user.branch ?? 'Not specified',
          ),
          if (user.dualBranch != null && user.dualBranch!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.menu_book_rounded,
              label: 'MSc Dual Branch',
              value: user.dualBranch!,
            ),
          ],
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.calendar_today_rounded,
            label: 'Academic Year',
            value: 'Year ${user.academicYear}',
          ),
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.timeline_rounded,
            label: 'Current Semester',
            value: 'Semester ${user.currentSemester ?? 1}',
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. Strategy & Pace Card
// ─────────────────────────────────────────────────────────────────────────────

class _StrategyCard extends StatelessWidget {
  final UserModel user;
  final String? endgame;
  final String? prepStyle;

  const _StrategyCard({required this.user, this.endgame, this.prepStyle});

  String _hoursForPace(String? pace) {
    switch (pace) {
      case 'Light':
        return '5 – 10 hrs / week';
      case 'Normal':
        return '15 – 25 hrs / week';
      case 'Packed':
        return '30+ hrs / week';
      default:
        return '15 – 25 hrs / week';
    }
  }

  @override
  Widget build(BuildContext context) {
    final capacity = user.studyCapacity ?? 'Normal';
    final hours = _hoursForPace(capacity);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_outlined, color: _kPrimary, size: 20),
              const SizedBox(width: 10),
              Text(
                'Study Strategy',
                style: GoogleFonts.googleSans(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.speed_rounded, color: Colors.white54, size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Study Pace',
                  style: GoogleFonts.googleSans(
                    color: Colors.white54,
                    fontSize: 13,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _kPrimary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kPrimary.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '$capacity Pace ($hours)',
                  style: GoogleFonts.googleSans(
                    color: const Color(0xFFD4A5FF),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (endgame != null && endgame!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.track_changes_rounded,
              label: 'Endgame Goal',
              value: endgame!,
            ),
          ],
          if (prepStyle != null && prepStyle!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.psychology_rounded,
              label: 'Exam Prep Style',
              value: prepStyle!,
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. Career Interests Card
// ─────────────────────────────────────────────────────────────────────────────

class _InterestsCard extends StatelessWidget {
  final List<String> interests;

  const _InterestsCard({required this.interests});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.work_outline_rounded,
                color: _kPrimary,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                'Career Interests',
                style: GoogleFonts.googleSans(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          interests.isEmpty
              ? Text(
                  'No career interests selected yet.',
                  style: GoogleFonts.googleSans(
                    color: Colors.white38,
                    fontSize: 13,
                  ),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: interests.map((interest) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _kPrimary.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _kPrimary.withValues(alpha: 0.4),
                          width: 1.0,
                        ),
                      ),
                      child: Text(
                        interest,
                        style: GoogleFonts.googleSans(
                          color: const Color(0xFFD4A5FF),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. Account & Actions Card
// ─────────────────────────────────────────────────────────────────────────────

class _AccountActionsCard extends StatelessWidget {
  final UserModel user;
  final VoidCallback onSignOut;

  const _AccountActionsCard({required this.user, required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.settings_outlined, color: _kPrimary, size: 20),
              const SizedBox(width: 10),
              Text(
                'Account Settings',
                style: GoogleFonts.googleSans(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _InfoRow(
            icon: Icons.mail_outline_rounded,
            label: 'Email',
            value: user.email.isNotEmpty ? user.email : 'Not set',
          ),
          const SizedBox(height: 20),
          Divider(color: Colors.white.withValues(alpha: 0.08)),
          const SizedBox(height: 12),

          // Edit / Re-run Onboarding button
          GestureDetector(
            onTap: () => context.go(AppRoutes.onboardingProfile),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.edit_note_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Update Profile & Preferences',
                    style: GoogleFonts.googleSans(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Sign Out button
          GestureDetector(
            onTap: onSignOut,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFCF6679).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFCF6679).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.logout_rounded,
                    color: Color(0xFFCF6679),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Sign Out',
                    style: GoogleFonts.googleSans(
                      color: const Color(0xFFCF6679),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared Info Row Helper
// ─────────────────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white54, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.googleSans(color: Colors.white54, fontSize: 13),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.googleSans(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
