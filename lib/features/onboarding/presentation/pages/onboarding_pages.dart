import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:Skolar/core/routing/app_routes.dart';
import 'package:Skolar/features/onboarding/presentation/providers/onboarding_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

const _kTotalSteps = 6;

const _kEndgameOptions = [
  'Placements/internships',
  'Higher studies',
  'Building my own thing',
  'Just want to do well',
  'Still figuring out',
];

const _kCareerInterests = [
  'AI/ML',
  'Web/App Dev',
  'Core CS/Systems',
  'CP',
  'Product/Design',
  'Not sure',
];

const _kPrepStyles = [
  'Steady all sem',
  'Cram near exam',
  'Depends on subject',
  'Not sure',
];

const _kDerailers = [
  'Procrastination',
  'Burnout',
  'Distraction',
  'Underestimating time',
  'Nothing',
];

const _kBufferPrefs = ['Always', 'Sometimes', 'Don\'t need it'];

const _kDailyCapacities = ['<1hr', '1-2hr', '2-4hr', '4+hr'];

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
  int _page = 0;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _advance() async {
    HapticFeedback.lightImpact();

    if (_page < _kTotalSteps - 1) {
      setState(() => _page++);
      _pageCtrl.animateToPage(
        _page,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      await ref.read(onboardingProvider.notifier).complete();
      if (mounted) context.go(AppRoutes.dashboard);
    }
  }

  void _back() {
    if (_page == 0) {
      context.go(AppRoutes.auth);
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _page--);
    _pageCtrl.animateToPage(
      _page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  bool _canAdvance() {
    final state = ref.watch(onboardingProvider);
    switch (_page) {
      case 0:
        return state.endgame != null;
      case 1:
        return state.careerInterests.isNotEmpty;
      case 2:
        return state.prepStyle != null;
      case 3:
        return state.derailer != null;
      case 4:
        return state.bufferPref != null;
      case 5:
        return state.dailyCapacity != null;
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF16161A), // Matches dark UI from mockup
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _back,
                    child: const Icon(
                      Icons.chevron_left,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Nova Setup',
                    style: GoogleFonts.googleSans(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Progress Bar
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 16.0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: List.generate(_kTotalSteps, (index) {
                        final isActive = index <= _page;
                        return Expanded(
                          child: Container(
                            height: 4,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: isActive ? Colors.white : Colors.white24,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  Text(
                    'STEP ${_page + 1}/$_kTotalSteps',
                    style: GoogleFonts.googleSans(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Main Content
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep(
                    title: "What's your endgame right now?",
                    subtitle:
                        "Nova will use this to balance your academic vs career focus.",
                    options: _kEndgameOptions,
                    isMultiSelect: false,
                    selectedValue: ref.watch(onboardingProvider).endgame,
                    onSelect: (val) {
                      ref.read(onboardingProvider.notifier).setEndgame(val);
                      Future.delayed(
                        const Duration(milliseconds: 300),
                        _advance,
                      );
                    },
                  ),
                  _buildStep(
                    title: "Career interests?",
                    subtitle: "Select all that apply.",
                    options: _kCareerInterests,
                    isMultiSelect: true,
                    selectedValues: ref
                        .watch(onboardingProvider)
                        .careerInterests,
                    onSelect: (val) {
                      ref
                          .read(onboardingProvider.notifier)
                          .toggleCareerInterest(val);
                    },
                  ),
                  _buildStep(
                    title: "How do you usually prep for exams?",
                    subtitle: "This helps Nova understand your study patterns.",
                    options: _kPrepStyles,
                    isMultiSelect: false,
                    selectedValue: ref.watch(onboardingProvider).prepStyle,
                    onSelect: (val) {
                      ref.read(onboardingProvider.notifier).setPrepStyle(val);
                      Future.delayed(
                        const Duration(milliseconds: 300),
                        _advance,
                      );
                    },
                  ),
                  _buildStep(
                    title: "What usually derails you?",
                    subtitle: "Nova will adapt to keep you on track.",
                    options: _kDerailers,
                    isMultiSelect: false,
                    selectedValue: ref.watch(onboardingProvider).derailer,
                    onSelect: (val) {
                      ref.read(onboardingProvider.notifier).setDerailer(val);
                      Future.delayed(
                        const Duration(milliseconds: 300),
                        _advance,
                      );
                    },
                  ),
                  _buildStep(
                    title: "Buffer time before practicals/labs?",
                    subtitle: "How should Nova schedule around your labs?",
                    options: _kBufferPrefs,
                    isMultiSelect: false,
                    selectedValue: ref.watch(onboardingProvider).bufferPref,
                    onSelect: (val) {
                      ref.read(onboardingProvider.notifier).setBufferPref(val);
                      Future.delayed(
                        const Duration(milliseconds: 300),
                        _advance,
                      );
                    },
                  ),
                  _buildStep(
                    title: "Realistic daily time on a normal day?",
                    subtitle:
                        "Nova will curate your focus list based on your availability.",
                    options: _kDailyCapacities,
                    isMultiSelect: false,
                    selectedValue: ref.watch(onboardingProvider).dailyCapacity,
                    onSelect: (val) {
                      ref
                          .read(onboardingProvider.notifier)
                          .setDailyCapacity(val);
                    },
                  ),
                ],
              ),
            ),

            // Footer (Sticky Button)
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: AnimatedOpacity(
                opacity: _canAdvance() ? 1.0 : 0.5,
                duration: const Duration(milliseconds: 200),
                child: IgnorePointer(
                  ignoring: !_canAdvance(),
                  child: InkWell(
                    onTap: _advance,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8C38E5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _page == _kTotalSteps - 1
                            ? 'Save Preference →'
                            : 'Continue →',
                        style: GoogleFonts.googleSans(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep({
    required String title,
    required String subtitle,
    required List<String> options,
    required bool isMultiSelect,
    String? selectedValue,
    List<String>? selectedValues,
    required Function(String) onSelect,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Hero(
                tag: 'mascot_hero',
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(shape: BoxShape.circle),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/mascot.jpeg',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.googleSans(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: GoogleFonts.googleSans(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          ...options.map((option) {
            final isSelected = isMultiSelect
                ? (selectedValues?.contains(option) ?? false)
                : (selectedValue == option);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: GestureDetector(
                onTap: () => onSelect(option),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF8C38E5).withOpacity(0.25)
                        : const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF8C38E5)
                          : Colors.white12,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          option,
                          style: GoogleFonts.googleSans(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontSize: 16,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: isMultiSelect
                              ? BoxShape.rectangle
                              : BoxShape.circle,
                          color: isSelected
                              ? const Color(0xFF8C38E5)
                              : Colors.transparent,
                          borderRadius: isMultiSelect
                              ? BorderRadius.circular(6)
                              : null,
                          border: isSelected
                              ? null
                              : Border.all(color: Colors.white54, width: 2),
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 16,
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
