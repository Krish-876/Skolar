import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nova/core/theme/app_theme.dart';
import 'package:nova/shared/providers/global_providers.dart';

class DashboardHeader extends ConsumerWidget {
  const DashboardHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          // ── Avatar (initials fallback — swap with CachedNetworkImage if you add avatarUrl to UserModel) ──
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppTheme.primaryGradient,
            ),
            child: Center(
              child: Text(
                user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                style: GoogleFonts.googleSans(
                  color: AppTheme.onPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // ── Welcome text ──────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back',
                  style: GoogleFonts.googleSans(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user.name,
                  style: GoogleFonts.manrope(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          // ── Notification bell ─────────────────────────────────────────────
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.surface.withOpacity(0.6),
            ),
            child: IconButton(
              icon: const Icon(
                Icons.notifications_none_rounded,
                color: AppTheme.textPrimary,
                size: 22,
              ),
              onPressed: () {
                // TODO: navigate to notifications
              },
            ),
          ),
        ],
      ),
    );
  }
}