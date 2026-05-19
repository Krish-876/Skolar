import 'package:flutter/material.dart';
import 'package:nova/core/routing/app_routes.dart';
import 'package:nova/core/theme/app_theme.dart';
import 'package:nova/features/auth/presentation/widgets/space_background.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _controller = PageController();
  int _page = 0;

  static const _steps = [
    ('Welcome to Nova', 'Your AI-powered exam companion.', Icons.auto_awesome),
    ('Track Syllabus',  'Stay on top of every topic.',     Icons.checklist_rounded),
    ('Predict Results', 'Get smarter with every test.',    Icons.insights_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ── Full-screen background gradient ──────────────────────────────────
      body: SpaceBackground(
        child: SafeArea(
          child: Column(
            children: [
              // ── Page content ─────────────────────────────────────────────
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemCount: _steps.length,
                  itemBuilder: (_, i) {
                    final (title, sub, icon) = _steps[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.lg,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Icon inside a glassy surface card
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusXxl,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: AppTheme.dropShadow,
                                  blurRadius: 24,
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Icon(
                              icon,
                              size: 56,
                              color: AppTheme.star, // accent pop
                            ),
                          ),

                          const SizedBox(height: AppTheme.xl),

                          // Title
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .displayMedium
                                ?.copyWith(
                                  fontSize: 26,
                                  color: AppTheme.onBackground,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),

                          const SizedBox(height: AppTheme.sm),

                          // Subtitle
                          Text(
                            sub,
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: AppTheme.onBackground2,
                                  fontSize: 15,
                                  height: 1.5,
                                ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // ── Dot indicators ───────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _steps.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.all(AppTheme.xs),
                    width: _page == i ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusSm),
                      color: _page == i
                          ? AppTheme.primary
                          : AppTheme.surfaceLight,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppTheme.lg),

              // ── CTA button ───────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.lg,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                      boxShadow: const [
                        BoxShadow(
                          color: AppTheme.dropShadow,
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: AppTheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusXl),
                        ),
                      ),
                      onPressed: () {
                        if (_page < _steps.length - 1) {
                          _controller.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        } else {
                          Navigator.pushNamed(context, AppRoutes.auth);
                        }
                      },
                      child: Text(
                        _page < _steps.length - 1 ? 'Next' : 'Get Started',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppTheme.xl),
            ],
          ),
        ),
      ),
    );
  }
}