import 'package:Skolar/place_holder.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:Skolar/features/auth/presentation/pages/auth_pages.dart';
import 'package:Skolar/features/onboarding/presentation/pages/onboarding_pages.dart';
import 'package:Skolar/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:Skolar/features/mock_tests/presentation/pages/mock_tests_pages.dart';
import 'package:Skolar/features/feed/presentation/pages/feed_page.dart';
import 'package:Skolar/features/focus_session/presentation/focus_timer_page.dart';
import 'package:Skolar/features/exam_prediction_with_bank/questions_feature/exam_prediction_pages.dart';
import 'package:Skolar/features/pyq_upload/presentation/pages/pyq_upload_pages.dart';
import 'package:Skolar/features/colleges/presentation/pages/colleges_pages.dart';
import 'package:Skolar/features/analytics/presentation/pages/analytics_pages.dart';
import 'package:Skolar/features/splash%20screen/splash_screen.dart';
import 'package:Skolar/core/loading/test_page.dart';

import '../../features/profile/presentation/pages/profile_pages1.dart';

class AppRoutes {
  static const String auth            = '/auth';
  static const String onboarding      = '/onboarding';
  static const String dashboard       = '/dashboard';
  static const String mockTests       = '/mock-tests';
  static const String feed            = '/feed';
  static const String focusSession    = '/focus-session';
  static const String examPrediction  = '/exam-prediction';
  static const String profile         = '/profile';
  static const String pyqUpload       = '/pyq-upload';
  static const String colleges        = '/colleges';
  static const String analytics       = '/analytics';
  static const String syllabus        = '/syllabus';
  static const String subjects        = '/subjects';
  static const String test            = '/test';
}

final goRouterProvider = GoRouter(
  initialLocation: AppRoutes.auth,
  redirect: (context, state) {
    final session  = Supabase.instance.client.auth.currentSession;
    final location = state.matchedLocation;
    final onAuth   = location == AppRoutes.auth;

    if (session == null && !onAuth) return AppRoutes.auth;
    if (session != null && onAuth)  return '/';

    return null;
  },
  routes: [
    // And add this route at the top of routes list:
    GoRoute(
      path: '/',
      builder: (_, __) => const _DevMenu(),
    ),
        
    GoRoute(
      path: AppRoutes.auth,
      builder: (_, __) => const AuthScreen(),
    ),
    GoRoute(
      path: AppRoutes.onboarding,
      builder: (_, __) => const OnboardingPage(),
    ),
    GoRoute(
      path: AppRoutes.dashboard,
      builder: (_, __) => const DashboardPage(),
    ),
    GoRoute(
      path: AppRoutes.analytics,
      builder: (_, __) => const AnalyticsPage(),
    ),
    GoRoute(
      path: AppRoutes.mockTests,
      builder: (_, __) => const MockTestPage(),
    ),
    GoRoute(
      path: AppRoutes.feed,
      builder: (_, __) => const FeedPage(),
    ),
    GoRoute(
      path: AppRoutes.focusSession,
      builder: (_, __) => const FocusTimerPage(),
    ),
    GoRoute(
      path: AppRoutes.examPrediction,
      builder: (_, __) => const ExamPredictionPage(),
    ),
    GoRoute(
      path: AppRoutes.profile,
      builder: (_, __) => const ProfilePage(),
    ),
    GoRoute(
      path: AppRoutes.pyqUpload,
      builder: (_, __) => const PyqUploadPage(),
    ),
    GoRoute(
      path: AppRoutes.colleges,
      builder: (_, __) => const CollegesPage(),
    ),
    GoRoute(
      path: AppRoutes.subjects,
      builder: (_, __) => const PlaceholderPage(title: 'Subjects'),
    ),
    GoRoute(
      path: AppRoutes.syllabus,
      builder: (_, __) => const SplashScreen(),
    ),
    GoRoute(
      path: AppRoutes.test,
      builder: (_, __) => const TestLoadingPage(),
    ),
  ],
);

class _DevMenu extends StatelessWidget {
  const _DevMenu();

  static const _pages = [
    ('Onboarding', AppRoutes.onboarding),
    ('Auth', AppRoutes.auth),
    ('Dashboard', AppRoutes.dashboard),
    ('Analytics', AppRoutes.analytics),
    ('Colleges', AppRoutes.colleges),
    ('Exam Prediction', AppRoutes.examPrediction),
    ('Mock Tests', AppRoutes.mockTests),
    ('Profile', AppRoutes.profile),
    ('PYQ Upload', AppRoutes.pyqUpload),
    ('Subjects', AppRoutes.subjects),
    ('Syllabus', AppRoutes.syllabus),
    ('Feed', AppRoutes.feed),
    ('Focus Session', AppRoutes.focusSession),
    ('Loading Screen', AppRoutes.test),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nova – Dev Menu'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _pages.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final (label, route) = _pages[i];
          return ListTile(
            title: Text(label),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            onTap: () => context.push(route),
          );
        },
      ),
    );
  }
}
