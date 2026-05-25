import 'package:flutter/material.dart';
import 'package:Skolar/core/routing/app_routes.dart';
import 'package:Skolar/core/theme/app_theme.dart';
import 'package:Skolar/core/widgets/glass_background.dart';
import 'package:Skolar/features/auth/presentation/widgets/space_background.dart'; // Using your GlassBackground file

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
      // ── Replaced GlassBackground location to wrap body appropriately ──
      body: GlassBackground(
        child: Column(
          children: [
            // ── Upper Half: Feature Images/Assets ────────────────────────────
            Expanded(
              flex: 5,
              child: PageView.builder(
                controller: _controller,
                physics: const NeverScrollableScrollPhysics(), // Managed via CTA button
                itemCount: _steps.length,
                itemBuilder: (_, i) {
                  // TODO: Replace with your actual image paths matching each onboarding step
                  return Container(
                    padding: const EdgeInsets.all(AppTheme.lg),
                    alignment: Alignment.center,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.asset(
                        'assets/images/onboarding_${i + 1}.jpg', 
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          // Fallback container using your original icon styling if image is missing
                          return Container(
                            width: 160,
                            height: 160,
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(_steps[i].$3, size: 72, color: AppTheme.star),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
                
            // ── Lower Half: Glassmorphism Text & Actions Card ────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(AppTheme.lg, 0, AppTheme.lg, AppTheme.xl),
              child: GlassCard(
                borderRadius: 40,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.lg,
                    vertical: 32,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Sub-PageView for syncing Text Elements
                      SizedBox(
                        height: 110, 
                        child: PageView.builder(
                          controller: _controller,
                          onPageChanged: (i) => setState(() => _page = i),
                          itemCount: _steps.length,
                          itemBuilder: (_, i) {
                            final (title, sub, _) = _steps[i];
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
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
                            );
                          },
                        ),
                      ),
                
                      // ── Dot indicators ─────────────────────────────────────
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
                              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                              color: _page == i
                                  ? AppTheme.onBackground
                                  : AppTheme.surfaceLight,
                            ),
                          ),
                        ),
                      ),
                
                      const SizedBox(height: AppTheme.xl),
                
                      // ── CTA button ─────────────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 56,
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
                                borderRadius: BorderRadius.circular(AppTheme.radiusXl),
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
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _page < _steps.length - 1 ? 'Next' : 'Get Started',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward, size: 18),
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
          ],
        ),
      ),
    );
  }
}