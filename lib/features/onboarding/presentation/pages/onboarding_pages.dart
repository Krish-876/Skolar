import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Skolar/core/routing/app_routes.dart';
import 'package:Skolar/core/theme/app_theme.dart';
import 'package:Skolar/core/widgets/glass_background.dart';
import 'package:Skolar/features/onboarding/presentation/providers/onboarding_provider.dart';
import 'package:Skolar/features/onboarding/presentation/widgets/onboarding_widgets.dart';
import 'package:go_router/go_router.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

const _kBitsBranches = [
  'CS',
  'ECE',
  'EEE',
  'Mech',
  'Civil',
  'Chem',
  'Bio',
  'Pharma',
  'ECON',
  'MSc Physics',
  'MSc Chem',
  'MSc Bio',
  'MSc Maths',
  'MSc Econ',
];

const _kStudyGoals = [
  '🏆 Top the sem',
  '✅ Clear all papers',
  '😅 Just pass bro',
  '🎯 9 pointer grind',
  '📚 Actually understand stuff',
  '⚡ Last minute warrior',
];

const _kIntroSteps = [
  ('Welcome to Nova', 'Your AI-powered exam companion.', Icons.auto_awesome),
  ('Track Syllabus', 'Stay on top of every topic.', Icons.checklist_rounded),
  ('Predict Results', 'Get smarter with every test.', Icons.insights_rounded),
];

const int _kIntroCount = 3;
const int _kTotalPages = _kIntroCount + 3;

// ─────────────────────────────────────────────────────────────────────────────
// OnboardingPage
// ─────────────────────────────────────────────────────────────────────────────

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage>
    with TickerProviderStateMixin {
  final _pageCtrl = PageController();
  final _nameCtrl = TextEditingController();
  int _page = 0;

  late final AnimationController _sectionCtrl;
  late final Animation<double> _sectionFade;

  bool get _inQuestionSection => _page >= _kIntroCount;
  int get _questionIndex => _page - _kIntroCount;

  @override
  void initState() {
    super.initState();
    _sectionCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      value: 1.0,
    );
    _sectionFade = CurvedAnimation(parent: _sectionCtrl, curve: Curves.easeOut);
    // Rebuild on every keystroke so _ctaEnabled re-evaluates instantly.
    _nameCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _nameCtrl.dispose();
    _sectionCtrl.dispose();
    super.dispose();
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  Future<void> _advance() async {
    // Dismiss keyboard before any navigation so it doesn't overlap the next step.
    FocusManager.instance.primaryFocus?.unfocus();
    HapticFeedback.lightImpact();

    if (_page < _kIntroCount - 1) {
      setState(() => _page++);
      _pageCtrl.animateToPage(
        _page,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
      );
      return;
    }

    if (_page == _kIntroCount - 1) {
      _sectionCtrl.reverse().then((_) {
        setState(() => _page = _kIntroCount);
        _sectionCtrl.forward();
      });
      return;
    }

    if (_page < _kTotalPages - 1) {
      _sectionCtrl.reverse().then((_) {
        setState(() => _page++);
        _sectionCtrl.forward();
      });
      return;
    }

    await ref.read(onboardingProvider.notifier).complete();
    if (mounted) context.go(AppRoutes.dashboard);
  }

  void _back() {
    if (_page == 0) return;
    HapticFeedback.selectionClick();
    if (_inQuestionSection) {
      _sectionCtrl.reverse().then((_) {
        setState(() => _page--);
        _sectionCtrl.forward();
      });
    } else {
      setState(() => _page--);
      _pageCtrl.animateToPage(
        _page,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
      );
    }
  }

  // ── CTA helpers ─────────────────────────────────────────────────────────────

  String get _ctaLabel {
    if (_page < _kIntroCount - 1) return 'Next';
    if (_page == _kIntroCount - 1) return "Let's go";
    if (_page < _kTotalPages - 1) return 'Continue';
    return 'Get Started';
  }

  bool get _ctaEnabled {
    if (!_inQuestionSection) return true;
    switch (_questionIndex) {
      case 0:
        // Drive from controller directly — no frame-delay vs provider round-trip.
        return _nameCtrl.text.trim().isNotEmpty;
      case 1:
        return ref.watch(onboardingProvider).branch != null;
      case 2:
        return ref.watch(onboardingProvider).studyGoal != null;
      default:
        return true;
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return GlassBackground(
      child: GestureDetector(
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity > 300 && _page > 0) {
            _back();
          } else if (velocity < -300 && _ctaEnabled) {
            _advance();
          }
        },
        child: Scaffold(
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: false,
          body: Column(
            children: [
              // Progress bar (question steps only)
              AnimatedOpacity(
                opacity: _inQuestionSection ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.lg,
                    AppTheme.sm,
                    AppTheme.lg,
                    0,
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: _back,
                        child: const Icon(
                          Icons.chevron_left_rounded,
                          color: AppTheme.onBackground2,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: AppTheme.sm),
                      Expanded(
                        child: Row(
                          children: List.generate(3, (i) {
                            final active = i <= _questionIndex;
                            return Expanded(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                height: 3,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(2),
                                  gradient: active
                                      ? AppTheme.primaryGradient
                                      : null,
                                  color: active
                                      ? null
                                      : Colors.white.withValues(alpha: 0.12),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Upper area
              Expanded(
                flex: 5,
                child: _inQuestionSection
                    ? _QuestionIllustration(index: _questionIndex)
                    : PageView.builder(
                        controller: _pageCtrl,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _kIntroCount,
                        itemBuilder: (_, i) => Container(
                          padding: const EdgeInsets.all(AppTheme.lg),
                          alignment: Alignment.center,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Image.asset(
                              'assets/images/onboarding_${i + 1}.jpg',
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                width: 160,
                                height: 160,
                                decoration: BoxDecoration(
                                  gradient: AppTheme.primaryGradient,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _kIntroSteps[i].$3,
                                  size: 72,
                                  color: AppTheme.star,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
              ),

              // Lower card — wrapped so keyboard never causes overflow
              AnimatedPadding(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                padding: EdgeInsets.fromLTRB(
                  AppTheme.lg,
                  0,
                  AppTheme.lg,
                  MediaQuery.of(context).viewInsets.bottom + AppTheme.xl,
                ),
                child: GlassCard(
                  borderRadius: 40,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.lg,
                      vertical: 32,
                    ),
                    child: FadeTransition(
                      opacity: _sectionFade,
                      child: _inQuestionSection
                          ? _buildQuestionCard()
                          : _buildIntroCard(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Intro card ──────────────────────────────────────────────────────────────

  Widget _buildIntroCard() {
    final (title, sub, _) = _kIntroSteps[_page];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 110,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: Column(
              key: ValueKey(_page),
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontSize: 26,
                    color: AppTheme.onBackground,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppTheme.sm),
                Text(
                  sub,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.onBackground2,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _kIntroCount,
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
        _CtaButton(label: _ctaLabel, enabled: true, onTap: _advance),
      ],
    );
  }

  // ── Question card ───────────────────────────────────────────────────────────

  Widget _buildQuestionCard() {
    final notifier = ref.read(onboardingProvider.notifier);
    final state = ref.watch(onboardingProvider);

    final Widget stepContent;
    switch (_questionIndex) {
      case 0:
        stepContent = QuestionStep(
          key: const ValueKey(0),
          question: "What should we call you? 👋",
          hint: "Just your first name or nickname is fine.",
          child: _NameField(
            controller: _nameCtrl,
            onChanged: notifier.setNickname,
          ),
        );
      case 1:
        stepContent = QuestionStep(
          key: const ValueKey(1),
          question: "What's your branch? 🎓",
          hint: "Pick the one on your ID card.",
          child: ChipGrid(
            options: _kBitsBranches,
            selected: state.branch,
            onSelected: notifier.setBranch,
          ),
        );
      default:
        stepContent = QuestionStep(
          key: const ValueKey(2),
          question: "What's the plan? 🎯",
          hint: "Be honest. We won't judge.",
          child: ChipGrid(
            options: _kStudyGoals,
            selected: state.studyGoal,
            onSelected: notifier.setStudyGoal,
          ),
        );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        stepContent,
        const SizedBox(height: AppTheme.xl),
        _CtaButton(
          label: _ctaLabel,
          enabled: _ctaEnabled,
          onTap: _ctaEnabled ? _advance : null,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _NameField
// ─────────────────────────────────────────────────────────────────────────────

class _NameField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _NameField({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      autofocus: true,
      textCapitalization: TextCapitalization.words,
      style: const TextStyle(
        color: AppTheme.onBackground,
        fontSize: 18,
        fontWeight: FontWeight.w500,
      ),
      cursorColor: AppTheme.onBackground2,
      decoration: InputDecoration(
        hintText: 'e.g. Krishna',
        hintStyle: TextStyle(
          color: AppTheme.onBackground2.withValues(alpha: 0.5),
          fontSize: 18,
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1.5,
          ),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppTheme.onBackground2, width: 2),
        ),
        contentPadding: const EdgeInsets.only(bottom: AppTheme.sm),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _QuestionIllustration
// ─────────────────────────────────────────────────────────────────────────────

class _QuestionIllustration extends StatelessWidget {
  final int index;
  const _QuestionIllustration({required this.index});

  static const _data = [
    ('👋', 'Nice to meet you'),
    ('🎓', 'Your department'),
    ('🎯', ''),
  ];

  @override
  Widget build(BuildContext context) {
    final (emoji, label) = _data[index.clamp(0, 2)];
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: Column(
        key: ValueKey(index),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 96)),
          const SizedBox(height: AppTheme.md),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.onBackground2,
              fontSize: 16,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CtaButton
// ─────────────────────────────────────────────────────────────────────────────

class _CtaButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback? onTap;

  const _CtaButton({required this.label, required this.enabled, this.onTap});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: enabled ? 1.0 : 0.4,
      duration: const Duration(milliseconds: 200),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            boxShadow: enabled
                ? const [
                    BoxShadow(
                      color: AppTheme.dropShadow,
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              foregroundColor: AppTheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusXl),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
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
    );
  }
}
