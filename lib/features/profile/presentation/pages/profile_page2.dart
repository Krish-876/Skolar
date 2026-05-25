import 'package:flutter/material.dart';
import 'package:Skolar/core/widgets/glass_background.dart';
import 'package:Skolar/features/profile/presentation/widgets/book_shelf_banner.dart';
import 'package:Skolar/features/profile/presentation/widgets/left_painter.dart';
import 'package:Skolar/features/profile/presentation/widgets/mascot.dart';
import 'package:Skolar/features/profile/presentation/widgets/quick_stats.dart';
import 'package:Skolar/features/profile/presentation/widgets/settings_glass.dart';
import 'package:Skolar/features/profile/presentation/widgets/streak_card.dart';

// ─────────────────────────────────────────────
//  ENTRY POINT – run directly to test
//  flutter run -t lib/features/dashboard/presentation/pages/dashboard_page.dart
// ─────────────────────────────────────────────
void main() {
  runApp(const SkolarDashboardApp());
}

class SkolarDashboardApp extends StatelessWidget {
  const SkolarDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nova – Dashboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColors.deepSpace,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.nebulaViolet,
          surface: AppColors.cardSurface,
        ),
      ),
      home: const ProfilePage2(),
    );
  }
}

// ─────────────────────────────────────────────
//  COLORS
// ─────────────────────────────────────────────
class AppColors {
  static const Color deepSpace          = Color(0xFF080B1A);
  static const Color cosmicNavy         = Color(0xFF0D1230);
  static const Color cardSurface        = Color(0xFF131B38);
  static const Color cardBorder         = Color(0xFF1F2D55);
  static const Color nebulaViolet       = Color(0xFF7B5EEF);
  static const Color softPurple         = Color(0xFFAA8FFF);
  static const Color accentPink         = Color(0xFFE05ECC);
  static const Color textPrimary        = Color(0xFFEEF0FF);
  static const Color textSecondary      = Color(0xFF7A84AA);
}

// ─────────────────────────────────────────────
//  MOCK DATA  (replace with Riverpod providers)
// ─────────────────────────────────────────────
class _MockUser {
  static const String name         = 'Krishna';
  static const String college      = 'BPHC';
  static const String email      = 'f20240175@hyderabad.bits-pilani.ac.in';
  static const String rollNumber   = '2025AAPS1010H';
}

// ─────────────────────────────────────────────
//  PAGE
// ─────────────────────────────────────────────
class ProfilePage2 extends StatefulWidget {
  const ProfilePage2({super.key});

  @override
  State<ProfilePage2> createState() => _ProfilePage2State();
}

class _ProfilePage2State extends State<ProfilePage2>
    with TickerProviderStateMixin {
  // ignore: unused_field
  final int _currentNav = 0;

  late final AnimationController _pulseController;
  late final AnimationController _slideController;
  late final Animation<double> _slideAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _slideAnim = CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic);
    _fadeAnim  = CurvedAnimation(parent: _slideController, curve: Curves.easeIn);

    _slideController.forward();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GlassBackground(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 60),
          child: Center(
            child: GlassCard(
              child: Stack(
                children: [
                  SafeArea(
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.04),
                          end: Offset.zero,
                        ).animate(_slideAnim),
                        child: CustomScrollView(
                          physics: const BouncingScrollPhysics(),
                          slivers: [
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(1, 60, 1, 0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
 Center(
  child: Column(
    children: [
      CircleAvatar(
        radius: 50,
        backgroundImage: const AssetImage(
          'assets/images/profile_placeholder.png',
        ),
        onBackgroundImageError: (_, __) {},
      ),

      const SizedBox(height: 20),

      const Text(
        _MockUser.name,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      SizedBox(height: 10,),
      const Text(
        _MockUser.email,
        style: TextStyle(
          fontSize: 12,
        ),
      ),
      SizedBox(height: 50,),
      CustomPaint(
        foregroundPainter: LeftHighlightPainter(),
        child: const SettingsGlassMenu()),
    ],
  ),
),
                                    
                                    
                                                                      ],
                                ),
                              ),
                              
                            ),
                          ],
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
}

// ─────────────────────────────────────────────
//  PROFILE HEADER  (only this stays in-page,
//  everything else is imported from widgets/)
// ─────────────────────────────────────────────
class _ProfileHeader extends StatelessWidget {
  final AnimationController pulseController;
  const _ProfileHeader({required this.pulseController});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardSurface.withOpacity(0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.nebulaViolet.withOpacity(0.12),
            blurRadius: 24,
            spreadRadius: -4,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          // ── MascotAvatar from widgets/mascot_avatar.dart ──
          MascotAvatar(
            assetPath: 'assets/images/mascot.jpeg',
            size: 76,
            animated: true,
          ),
          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _MockUser.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 2,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _MockUser.college,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _MockUser.rollNumber,
                  style: const TextStyle(
                    color: AppColors.softPurple,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),

          GestureDetector(
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Settings – coming soon')),
            ),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.cosmicNavy,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: const Icon(
                Icons.settings_outlined,
                color: AppColors.textSecondary,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  COMMITMENT LINK
// ─────────────────────────────────────────────
class _CommitmentLink extends StatelessWidget {
  final VoidCallback onTap;
  const _CommitmentLink({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: const Row(
        children: [
          Text(
            'Check your commitment here',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          
          SizedBox(width: 4),
          Icon(Icons.arrow_forward, color: AppColors.textSecondary, size: 14),
          
        ],
      ),
    );
  }
}