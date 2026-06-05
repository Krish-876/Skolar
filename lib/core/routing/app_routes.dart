import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:Skolar/features/auth/presentation/pages/pages.dart';
import 'package:Skolar/features/colleges/presentation/pages/colleges_pages.dart';
import 'package:Skolar/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:Skolar/features/focus_session/presentation/focus_timer_page.dart';
import 'package:Skolar/features/profile/presentation/pages/profile_page2.dart';


/// Application routes
class AppRoutes {
  // Auth routes
  static const String auth = '/auth';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';

  // Onboarding route
  static const String onboarding = '/onboarding';

  // Main app routes
  static const String dashboard = '/dashboard';
  static const String colleges = '/colleges';
  static const String subjects = '/subjects';
  static const String syllabus = '/syllabus';
  static const String pyqUpload = '/pyq-upload';
  static const String examPrediction = '/exam-prediction';
  static const String analytics = '/analytics';
  static const String mockTests = '/mock-tests';
  static const String profile = '/profile';

  // Nested routes
  static const String collegeDetail = 'detail';
  static const String subjectDetail = 'detail';

  static const focusSession = '/focus-session';
}

/// GoRouter configuration
final goRouterProvider = GoRouter(
  initialLocation: AppRoutes.dashboard,
  routes: [
    // Auth routes
    GoRoute(
      path: AppRoutes.auth,
      builder: (context, state) => const AuthScreen(),
    ),
    GoRoute(
      path: AppRoutes.register,
      builder: (context, state) => const SizedBox(),
    ),

    // Main routes
    GoRoute(
      path: AppRoutes.dashboard,
      builder: (context, state) => const SizedBox(),
    ),
    GoRoute(
      path: AppRoutes.colleges,
      builder: (context, state) => const SizedBox(),
      routes: [
        GoRoute(
          path: AppRoutes.collegeDetail,
          builder: (context, state) => const SizedBox(),
        ),
      ],
    ),
    GoRoute(
      path: AppRoutes.profile,
      builder: (context, state) => const SizedBox(),
    ),
    // Main routes
    GoRoute(
      path: AppRoutes.dashboard,
      builder: (context, state) => const DashboardPage(),
    ),
    GoRoute(
      path: AppRoutes.colleges,
      builder: (context, state) => const CollegesPage(),
      routes: [
        GoRoute(
          path: AppRoutes.collegeDetail,
          builder: (context, state) => const SizedBox(),
        ),
      ],
    ),
    GoRoute(
      path: AppRoutes.profile,
      builder: (context, state) => const SkolarDashboardApp(),
    ),
    GoRoute(
      path: AppRoutes.focusSession,
      builder: (context, state) => FocusTimerPage(),
    ),
  ],
);
