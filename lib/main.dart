import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nova/features/analytics/presentation/pages/analytics_pages.dart';
import 'package:nova/features/auth/presentation/pages/auth_pages.dart';
import 'package:nova/features/colleges/presentation/pages/colleges_pages.dart';
import 'package:nova/features/dashboard/presentation/pages/dashboard_pages.dart';
import 'package:nova/features/exam_prediction_with_bank/questions_feature/exam_prediction_pages.dart';
import 'package:nova/features/feed/presentation/pages/feed_page.dart';
import 'package:nova/features/mock_tests/presentation/pages/mock_tests_pages.dart';
import 'package:nova/features/mock_tests/presentation/widgets/mock_tests_widgets.dart';
import 'package:nova/features/onboarding/presentation/pages/onboarding_pages.dart';
import 'package:nova/features/profile/presentation/pages/profile_pages1.dart';
// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------
import 'package:flutter/services.dart';
import 'package:nova/space_record.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    ),
  );
  runApp(const ProviderScope(child: NovaApp()));
}
// ---------------------------------------------------------------------------
// App root
// ---------------------------------------------------------------------------
class NovaApp extends StatelessWidget {
  const NovaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nova',
      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        brightness: Brightness.dark,

        scaffoldBackgroundColor: Colors.black,
        canvasColor: Colors.black,

        colorScheme: ColorScheme.dark(
          primary: Colors.deepPurple,
          surface: Colors.black,
        ),

        useMaterial3: true,
      ),

      initialRoute: AppRoutes.home,
      routes: AppRoutes.routes,
    );
  }
}
// ---------------------------------------------------------------------------
// Routes
// ---------------------------------------------------------------------------
abstract class AppRoutes {
  static const home = '/';
  static const onboarding = '/onboarding';
  static const auth = '/auth';
  static const dashboard = '/dashboard';
  static const analytics = '/analytics';
  static const colleges = '/colleges';
  static const examPrediction = '/exam-prediction';
  static const mockTests = '/mock-tests';
  static const profile = '/profile';
  static const pyqUpload = '/pyq-upload';
  static const subjects = '/subjects';
  static const syllabus = '/syllabus';
  static const feed = '/feed';

  static final Map<String, WidgetBuilder> routes = {
  home: (_) => const _DevMenu(),
  onboarding: (_) => const OnboardingPage(),
  auth: (_) => const AuthScreen(),
  dashboard: (_) => const DashboardPage(),
  analytics: (_) => const AnalyticsPage(),
  feed: (_) => const FeedPage(),         // ← add this
  colleges: (_) => const CollegesPage(),
  examPrediction: (_) => const ExamPredictionPage(),
  mockTests: (_) => const MockTestPage(),
  profile: (_) => const SkolarDashboardApp(),
  pyqUpload: (_) => const SpaceRecordPage(),
  subjects: (_) => const _PlaceholderPage(title: 'Subjects'),
  syllabus: (_) => const _PlaceholderPage(title: 'Syllabus'),
};
}

// ---------------------------------------------------------------------------
// Dev menu – lets you tap into any page while building
// ---------------------------------------------------------------------------
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
            onTap: () => Navigator.pushNamed(context, route),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Generic placeholder – swap out with the real page as you build each one
// ---------------------------------------------------------------------------
class _PlaceholderPage extends StatelessWidget {
  final String title;
  const _PlaceholderPage({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.construction_rounded,
                size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Page not built yet',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}