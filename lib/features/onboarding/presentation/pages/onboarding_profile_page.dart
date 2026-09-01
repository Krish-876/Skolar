// ─────────────────────────────────────────────────────────────────────────────
// Unified Onboarding Flow — 7 steps in a single route.
//
// Step 0 : Avatar customiser → name / BITS ID
// Step 1 : Confirm institution (auto-detected from email)
// Step 2 : Academic details  (branch, dual-degree, year, semester)
// Step 3 : Study capacity    (Light / Normal / Packed)
// Step 4 : Endgame goal      (single-select)
// Step 5 : Career interests  (multi-select)
// Step 6 : Prep style        (single-select)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:avatar_maker/avatar_maker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:Skolar/core/routing/app_routes.dart';
import 'package:Skolar/core/theme/app_theme.dart';
import 'package:Skolar/features/onboarding/presentation/providers/onboarding_provider.dart';
import 'package:Skolar/shared/components/framed_avatar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Bundled asset font (see pubspec.yaml `fonts:` — family `GoogleSans`,
// assets/fonts/GoogleSans-*.ttf). Referenced by fontFamily string, matching
// how the auth screens already reference the same bundled family.
const _kFontFamily = 'GoogleSans';

// ─────────────────────────────────────────────────────────────────────────────
// Constants & Options
// ─────────────────────────────────────────────────────────────────────────────

const _kTotalSteps = 8;

const _kEndgameOptions = [
  'Placements / internships',
  'Higher studies',
  'Building my own thing',
  'Just want to do well',
  'Still figuring out',
];

const _kCareerInterests = [
  'AI / ML',
  'Web / App Dev',
  'Core CS / Systems',
  'Competitive Programming',
  'Product / Design',
  'Not sure yet',
];

const _kCareerInterestIcons = <String, IconData>{
  'AI / ML': Icons.psychology_rounded,
  'Web / App Dev': Icons.web_rounded,
  'Core CS / Systems': Icons.memory_rounded,
  'Competitive Programming': Icons.emoji_events_rounded,
  'Product / Design': Icons.palette_rounded,
  'Not sure yet': Icons.help_outline_rounded,
};

const _kPrepStyles = [
  'Steady all semester',
  'Cram near exams',
  'Depends on subject',
  'Not sure',
];

// ─────────────────────────────────────────────────────────────────────────────
// Capacity option data model
// ─────────────────────────────────────────────────────────────────────────────

class _CapacityOption {
  final String value;
  final String title;
  final String description;
  final String hours;
  final IconData icon;

  const _CapacityOption({
    required this.value,
    required this.title,
    required this.description,
    required this.hours,
    required this.icon,
  });
}

const _kCapacityOptions = [
  _CapacityOption(
    value: 'Light',
    title: 'Light Pace',
    description:
        'Perfect for maintaining steady progress without feeling overwhelmed. Focus on core exam topics.',
    hours: '5 – 10 HOURS / WEEK',
    icon: Icons.bolt_outlined,
  ),
  _CapacityOption(
    value: 'Normal',
    title: 'Normal Pace',
    description:
        'The balanced BITSian approach. Nova covers your handouts, daily quizzes, and revision cycles.',
    hours: '15 – 25 HOURS / WEEK',
    icon: Icons.timeline_outlined,
  ),
  _CapacityOption(
    value: 'Packed',
    title: 'Packed Pace',
    description:
        'Intensive prep for peak performance. Deep dives into all resources, PYQs, and complex problem sets.',
    hours: '30+ HOURS / WEEK',
    icon: Icons.local_fire_department_outlined,
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// OnboardingProfilePage — entry point, hosts the full 8-step flow
// ─────────────────────────────────────────────────────────────────────────────

class OnboardingProfilePage extends ConsumerStatefulWidget {
  const OnboardingProfilePage({super.key});

  @override
  ConsumerState<OnboardingProfilePage> createState() =>
      _OnboardingProfilePageState();
}

class _OnboardingProfilePageState extends ConsumerState<OnboardingProfilePage>
    with TickerProviderStateMixin {
  // ── Step management ────────────────────────────────────────────────────────
  int _step = 0;
  bool _isLoading = false;

  // ── Progress bar fill animation ───────────────────────────────────────────
  late AnimationController _progressCtrl;
  late Animation<double> _progressFill; // 0→1 for the current segment

  // ── Step 0 & 1 : Avatar & Profile ─────────────────────────────────────────
  final _nameCtrl = TextEditingController();
  final _idCtrl = TextEditingController();
  late final AvatarMakerController _avatarMakerController;

  // ── Step 2 : Institution ──────────────────────────────────────────────────
  String _campusName = 'BITS Pilani';
  String _campusLocation = 'Pilani Campus';
  String _campusDomain = '@pilani.bits-pilani.ac.in';

  // ── Step 3 : Academic details ─────────────────────────────────────────────
  String? _branch;
  bool _isDualDegree = false;
  String? _dualBranch;
  int? _currentYear;
  int? _currentSemester;

  // ── Step 4 : Study capacity ───────────────────────────────────────────────
  String? _studyCapacity;

  @override
  void initState() {
    super.initState();
    _avatarMakerController = NonPersistentAvatarMakerController();

    // Progress bar fill animation (plays each time step advances)
    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _progressFill = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _progressCtrl, curve: Curves.easeOut));

    _progressCtrl.forward();

    _extractCampusFromEmail();
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    _nameCtrl.dispose();
    _idCtrl.dispose();
    super.dispose();
  }

  // ── Campus auto-detection ─────────────────────────────────────────────────
  void _extractCampusFromEmail() {
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';
    if (email.endsWith('@hyderabad.bits-pilani.ac.in')) {
      _campusName = 'BITS Pilani';
      _campusLocation = 'Hyderabad Campus';
      _campusDomain = '@hyderabad.bits-pilani.ac.in';
    } else if (email.endsWith('@goa.bits-pilani.ac.in')) {
      _campusName = 'BITS Pilani';
      _campusLocation = 'Goa Campus';
      _campusDomain = '@goa.bits-pilani.ac.in';
    } else if (email.endsWith('@pilani.bits-pilani.ac.in')) {
      _campusName = 'BITS Pilani';
      _campusLocation = 'Pilani Campus';
      _campusDomain = '@pilani.bits-pilani.ac.in';
    }
  }

  // ── Navigation helpers ────────────────────────────────────────────────────
  void _playStepEntrance() {
    _progressCtrl
      ..reset()
      ..forward();
  }

  void _advance() async {
    if (_isLoading) return;
    HapticFeedback.lightImpact();

    _persistCurrentStep();

    if (_step < _kTotalSteps - 1) {
      setState(() => _step++);
      _playStepEntrance();
    } else {
      setState(() => _isLoading = true);
      try {
        await ref.read(onboardingProvider.notifier).complete();
        if (mounted) context.go(AppRoutes.subjects);
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _back() {
    HapticFeedback.selectionClick();

    if (_step == 0) {
      context.go(AppRoutes.auth);
      return;
    }

    setState(() => _step--);
    _playStepEntrance();
  }

  /// Flush local UI state into the Riverpod notifier before moving on.
  void _persistCurrentStep() {
    final n = ref.read(onboardingProvider.notifier);
    switch (_step) {
      case 0:
        n.setAvatarData(_avatarMakerController.displayedAvatarSVG);
      case 1:
        n.setName(_nameCtrl.text.trim());
        n.setId(_idCtrl.text.trim());
      case 2:
        n.setCampus(_campusDomain.split('@').last.split('.').first);
      case 3:
        if (_branch != null) n.setBranch(_branch!);
        n.setDualBranch(_dualBranch);
        if (_currentYear != null) n.setCurrentYear(_currentYear!);
        if (_currentSemester != null) n.setCurrentSemester(_currentSemester!);
      case 4:
        if (_studyCapacity != null) n.setStudyCapacity(_studyCapacity!);
    }
  }

  // ── Can-advance gate ──────────────────────────────────────────────────────
  bool _canAdvance() {
    final s = ref.watch(onboardingProvider);
    switch (_step) {
      case 0:
        return true; // Avatar customization is always ready
      case 1:
        return _nameCtrl.text.trim().isNotEmpty &&
            _idCtrl.text.trim().isNotEmpty;
      case 2:
        return true; // Campus confirmation
      case 3:
        return _branch != null &&
            _currentYear != null &&
            _currentSemester != null &&
            (!_isDualDegree || _dualBranch != null);
      case 4:
        return _studyCapacity != null;
      case 5:
        return s.endgame != null;
      case 6:
        return s.careerInterests.isNotEmpty;
      case 7:
        return s.prepStyle != null;
      default:
        return false;
    }
  }

  /// Steps that ask the user to make a choice get a "Prefer not to choose"
  /// link under the CTA (in addition to the top-bar Skip).
  bool _stepAsksForChoice(int step) => const {2, 4, 5, 6, 7}.contains(step);

  String _buttonLabel() {
    if (_step == 0) return 'Confirm Avatar →';
    if (_step == 2) return 'Yes, continue →';
    if (_step == _kTotalSteps - 1) return 'Save Preferences →';
    return 'Continue →';
  }

  String _mascotMessage() {
    switch (_step) {
      case 0:
        return "Let's create your digital twin! Customise your avatar below.";
      case 1:
        return "Looking good! Now, what should I call you?";
      case 2:
        return "I've automatically detected your institution based on your BITS email. Is this the campus you're currently attending?";
      case 3:
        return "Tell me about your academic setup — I'll personalise your study plan around it.";
      case 4:
        return "Nova will curate your focus list based on your availability. You can change this anytime in settings.";
      case 5:
        return "What's your endgame right now? Nova will use this to balance your academic vs career focus.";
      case 6:
        return "Select all the areas that interest you — I'll weight resources accordingly.";
      case 7:
        return "How do you usually prep for exams? This helps Nova understand your study patterns.";
      default:
        return '';
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final canAdvance = _canAdvance();
    return Scaffold(
      backgroundColor: AppTheme.background,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            _StepTopBar(
              step: _step,
              total: _kTotalSteps,
              fillAnim: _progressFill,
              onBack: _back,
              onSkip: _isLoading ? () {} : _advance,
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 360),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.05),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(
                  key: ValueKey('step_$_step'),
                  child: _buildCurrentStep(),
                ),
              ),
            ),
            if (_step != 4)
              _FooterButton(
                label: _buttonLabel(),
                enabled: canAdvance,
                isLoading: _isLoading,
                onTap: _advance,
              ),
            if (_stepAsksForChoice(_step))
              Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.md),
                child: Center(
                  child: TextButton(
                    onPressed: _isLoading ? null : _advance,
                    child: const Text(
                      'Prefer not to choose',
                      style: TextStyle(
                        fontFamily: _kFontFamily,
                        color: AppTheme.textMuted,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
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

  Widget _buildCurrentStep() {
    switch (_step) {
      case 0:
        return _AvatarStep(
          avatarController: _avatarMakerController,
          mascotMessage: _mascotMessage(),
        );
      case 1:
        return _BasicInfoStep(
          avatarController: _avatarMakerController,
          nameCtrl: _nameCtrl,
          idCtrl: _idCtrl,
          mascotMessage: _mascotMessage(),
          onTextChanged: () => setState(() {}),
        );
      case 2:
        return _InstitutionStep(
          campusName: _campusName,
          campusLocation: _campusLocation,
          campusDomain: _campusDomain,
          mascotMessage: _mascotMessage(),
          onChangeCampus: _changeCampus,
        );
      case 3:
        return _AcademicStep(
          branch: _branch,
          isDualDegree: _isDualDegree,
          dualBranch: _dualBranch,
          currentYear: _currentYear,
          currentSemester: _currentSemester,
          mascotMessage: _mascotMessage(),
          onBranchChanged: (v) => setState(() => _branch = v),
          onDualToggle: (v) => setState(() {
            _isDualDegree = v;
            if (!v) _dualBranch = null;
          }),
          onDualBranchChanged: (v) => setState(() => _dualBranch = v),
          onYearChanged: (v) => setState(() => _currentYear = v),
          onSemesterChanged: (v) => setState(() => _currentSemester = v),
        );
      case 4:
        return _CapacityStep(
          selected: _studyCapacity,
          mascotMessage: _mascotMessage(),
          onSelect: (v) => setState(() => _studyCapacity = v),
          onConfirm: _advance,
        );
      case 5:
        return _EndgameStep(
          mascotMessage: _mascotMessage(),
          selected: ref.watch(onboardingProvider).endgame,
          onSelect: (val) {
            ref.read(onboardingProvider.notifier).setEndgame(val);
          },
        );
      case 6:
        return _InterestsStep(
          mascotMessage: _mascotMessage(),
          selected: ref.watch(onboardingProvider).careerInterests,
          onToggle: (val) =>
              ref.read(onboardingProvider.notifier).toggleCareerInterest(val),
        );
      case 7:
        return _PrepStyleStep(
          mascotMessage: _mascotMessage(),
          selected: ref.watch(onboardingProvider).prepStyle,
          onSelect: (val) {
            ref.read(onboardingProvider.notifier).setPrepStyle(val);
          },
        );
      default:
        return const SizedBox.shrink();
    }
  }

  // ── Campus picker bottom sheet ─────────────────────────────────────────────
  void _changeCampus() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXxxl),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.onboardingButtonBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Choose Campus',
              style: TextStyle(
                fontFamily: _kFontFamily,
                color: AppTheme.onBackground,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _campusTile(
              ctx,
              'BITS Pilani',
              'Pilani Campus',
              '@pilani.bits-pilani.ac.in',
            ),
            _campusTile(
              ctx,
              'BITS Pilani',
              'Goa Campus',
              '@goa.bits-pilani.ac.in',
            ),
            _campusTile(
              ctx,
              'BITS Pilani',
              'Hyderabad Campus',
              '@hyderabad.bits-pilani.ac.in',
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _campusTile(
    BuildContext ctx,
    String name,
    String location,
    String domain,
  ) {
    final isCurrent = _campusLocation == location;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isCurrent
              ? AppTheme.accentPurple.withValues(alpha: 0.2)
              : AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          Icons.business_rounded,
          color: isCurrent ? AppTheme.accentPurple : AppTheme.textMuted,
          size: 18,
        ),
      ),
      title: Text(
        '$name, $location',
        style: const TextStyle(
          fontFamily: _kFontFamily,
          color: AppTheme.onBackground,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        domain,
        style: const TextStyle(
          fontFamily: _kFontFamily,
          color: AppTheme.textMuted,
          fontSize: 12,
        ),
      ),
      trailing: isCurrent
          ? const Icon(
              Icons.check_circle_rounded,
              color: AppTheme.accentPurple,
              size: 20,
            )
          : null,
      onTap: () {
        setState(() {
          _campusName = name;
          _campusLocation = location;
          _campusDomain = domain;
        });
        Navigator.pop(ctx);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared Widgets
// ─────────────────────────────────────────────────────────────────────────────

/// Top bar: back arrow, segmented progress dashes (centred), plain-text
/// Skip on the right.
class _StepTopBar extends StatelessWidget {
  final int step;
  final int total;
  final Animation<double> fillAnim;
  final VoidCallback onBack;
  final VoidCallback onSkip;

  const _StepTopBar({
    required this.step,
    required this.total,
    required this.fillAnim,
    required this.onBack,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            icon: const Icon(Icons.chevron_left, size: 22),
            color: AppTheme.onBackground,
          ),
          Expanded(
            child: Row(
              children: List.generate(total, (i) {
                final isPast = i < step;
                final isCurrent = i == step;
                return Expanded(
                  child: Container(
                    margin: EdgeInsets.only(right: i < total - 1 ? 5 : 0),
                    height: 3.5,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: AppTheme.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: isPast
                        ? Container(color: AppTheme.accentPurple)
                        : isCurrent
                        ? AnimatedBuilder(
                            animation: fillAnim,
                            builder: (_, _) => FractionallySizedBox(
                              widthFactor: fillAnim.value,
                              alignment: Alignment.centerLeft,
                              child: Container(color: AppTheme.accentPurple),
                            ),
                          )
                        : null,
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: 4),
          TextButton(
            onPressed: onSkip,
            style: TextButton.styleFrom(
              minimumSize: const Size(44, 44),
              padding: const EdgeInsets.symmetric(horizontal: 6),
            ),
            child: const Text(
              'Skip',
              style: TextStyle(
                fontFamily: _kFontFamily,
                color: AppTheme.accentPurple,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Centred illustration + large two-line headline + supporting body copy —
/// shared header shape for every onboarding step.
class _StepHeader extends StatelessWidget {
  final Widget illustration;
  final String headline;
  final String body;

  const _StepHeader({
    required this.illustration,
    required this.headline,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Center(child: illustration),
        const SizedBox(height: 24),
        Text(
          headline,
          textAlign: TextAlign.center,
          maxLines: 2,
          style: const TextStyle(
            fontFamily: _kFontFamily,
            color: AppTheme.onBackground,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          body,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: _kFontFamily,
            color: AppTheme.textMuted,
            fontSize: 14,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

/// Generic icon-in-circle illustration for steps that don't have a bespoke
/// preview (avatar) of their own.
class _IconIllustration extends StatelessWidget {
  final IconData icon;

  const _IconIllustration({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.accentPurple.withValues(alpha: 0.14),
        border: Border.all(
          color: AppTheme.accentPurple.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Icon(icon, color: AppTheme.accentPurple, size: 40),
    );
  }
}

/// 3D tactile chunky button matching OnboardingWelcomePage and AuthPreviewPage
class _FooterButton extends StatefulWidget {
  final String label;
  final bool enabled;
  final bool isLoading;
  final VoidCallback onTap;

  const _FooterButton({
    required this.label,
    required this.enabled,
    this.isLoading = false,
    required this.onTap,
  });

  @override
  State<_FooterButton> createState() => _FooterButtonState();
}

class _FooterButtonState extends State<_FooterButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && !widget.isLoading;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.lg,
        AppTheme.sm,
        AppTheme.lg,
        AppTheme.lg,
      ),
      child: AnimatedOpacity(
        opacity: widget.enabled ? 1.0 : 0.4,
        duration: const Duration(milliseconds: 200),
        child: IgnorePointer(
          ignoring: !active,
          child: GestureDetector(
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 60),
              transform: (_pressed && active)
                  ? Matrix4.translationValues(0, 4, 0)
                  : Matrix4.identity(),
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                color: widget.enabled
                    ? AppTheme.accentPurple
                    : AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                boxShadow: (widget.enabled && !_pressed)
                    ? AppTheme.chunkyButtonShadow
                    : [],
              ),
              alignment: Alignment.center,
              child: widget.isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppTheme.onPrimary,
                      ),
                    )
                  : Text(
                      widget.label,
                      style: const TextStyle(
                        fontFamily: _kFontFamily,
                        color: AppTheme.onPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step Widgets
// ─────────────────────────────────────────────────────────────────────────────

// ── Step 0: Avatar Customisation ─────────────────────────────────────────────

class _AvatarStep extends StatefulWidget {
  final AvatarMakerController avatarController;
  final String mascotMessage;

  const _AvatarStep({
    required this.avatarController,
    required this.mascotMessage,
  });

  @override
  State<_AvatarStep> createState() => _AvatarStepState();
}

class _AvatarStepState extends State<_AvatarStep> {
  static const double _customizerCardHeight = 320;
  final GlobalKey _customizerKey = GlobalKey();

  ScrollableState? _findHorizontalScrollable(BuildContext? rootContext) {
    if (rootContext == null) return null;
    ScrollableState? found;
    void visitor(Element element) {
      if (found != null) return;
      final widget = element.widget;
      if (widget is Scrollable) {
        if (element is StatefulElement && element.state is ScrollableState) {
          final state = element.state as ScrollableState;
          if (state.axisDirection == AxisDirection.left ||
              state.axisDirection == AxisDirection.right) {
            found = state;
            return;
          }
        }
      }
      element.visitChildren(visitor);
    }

    if (rootContext is Element) {
      rootContext.visitChildren(visitor);
    }
    return found;
  }

  void _switchCategory(bool forward) {
    final scrollable = _findHorizontalScrollable(_customizerKey.currentContext);
    if (scrollable != null && scrollable.position.hasPixels) {
      final pos = scrollable.position;
      final step = pos.viewportDimension > 0 ? pos.viewportDimension : 300.0;
      final target = forward ? (pos.pixels + step) : (pos.pixels - step);

      double destination;
      if (forward && target > pos.maxScrollExtent + 1.0) {
        destination = pos.minScrollExtent;
      } else if (!forward && target < pos.minScrollExtent - 1.0) {
        destination = pos.maxScrollExtent;
      } else {
        destination = target.clamp(pos.minScrollExtent, pos.maxScrollExtent);
      }

      if ((destination - pos.pixels).abs() > 0.5) {
        pos.animateTo(
          destination,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StepHeader(
            illustration: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.accentPurple.withValues(alpha: 0.6),
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accentPurple.withValues(alpha: 0.2),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: FramedAvatar(
                size: 104,
                backgroundColor: AppTheme.white,
                controller: widget.avatarController,
              ),
            ),
            headline: 'Create your avatar',
            body: widget.mascotMessage,
          ),
          const SizedBox(height: 20),
          _GlassCard(
            height: _customizerCardHeight,
            child: LayoutBuilder(
              builder: (context, constraints) {
                // The package always renders each choice's icon at a fixed
                // 80px regardless of column count or theme, and always adds
                // its own bottom icon strip (a TabBar switching between
                // categories) below the grid with no way to disable it —
                // the top title+arrows heading stays, since that's the
                // only other way to move between categories.
                //
                // To make each choice genuinely smaller (not just more
                // tightly packed, which risks the fixed-size icon
                // overflowing a too-small cell), the whole picker is laid
                // out oversized at `1/kTileScale` its real footprint, then
                // visually shrunk back down with Transform.scale. That
                // keeps every cell comfortably larger than the 80px icon
                // pre-scale, while what's on screen ends up smaller.
                const kTileScale = 0.75;
                final visibleWidth = constraints.maxWidth;
                final visibleHeight = constraints.maxHeight;
                final preScaleWidth = visibleWidth / kTileScale;
                final preScaleVisibleHeight = visibleHeight / kTileScale;
                // Same self-referential solve as before (strip height N
                // such that N == (preScaleVisibleHeight + N) * 0.1 + 16),
                // just carried out in pre-scale units. Deliberately rounds
                // down: undershooting just leaves a sliver of blank card
                // below the grid, but overshooting would clip real choices.
                final bottomNavEstimate =
                    ((preScaleVisibleHeight * 0.1 + 16) / 0.9).floorToDouble();
                final preScaleHeight =
                    preScaleVisibleHeight + bottomNavEstimate;
                return ClipRect(
                  child: SizedBox(
                    width: visibleWidth,
                    height: visibleHeight,
                    child: OverflowBox(
                      minWidth: preScaleWidth,
                      maxWidth: preScaleWidth,
                      minHeight: preScaleHeight,
                      maxHeight: preScaleHeight,
                      alignment: Alignment.topLeft,
                      // Transform.scale must be OverflowBox's child, not
                      // its parent: OverflowBox's own hit-test rejects any
                      // touch outside its own (small, pre-transform)
                      // reported size before it even looks at its child,
                      // so with Transform on the outside, taps anywhere
                      // past ~75% across (the inverse-scaled coordinate
                      // exceeding that small size) were silently dropped —
                      // exactly the 4th-column dead zone this fixes. With
                      // OverflowBox outermost, its size-check runs in the
                      // untransformed (correct, always-in-bounds) screen
                      // space, and Transform's own hit-test override — one
                      // level in — correctly remaps the touch into the
                      // full pre-scale coordinate space the customiser
                      // actually lays out in.
                      child: Transform.scale(
                        scale: kTileScale,
                        alignment: Alignment.topLeft,
                        child: Stack(
                          children: [
                            KeyedSubtree(
                              key: _customizerKey,
                              child: AvatarMakerCustomizer(
                                controller: widget.avatarController,
                                scaffoldWidth: preScaleWidth,
                                scaffoldHeight: preScaleHeight,
                                theme: AvatarMakerThemeData(
                                  primaryBgColor: AppTheme.transparent,
                                  secondaryBgColor: AppTheme.transparent,
                                  iconColor: AppTheme.onSurfaceDark,
                                  selectedIconColor: AppTheme.primary,
                                  unselectedIconColor:
                                      AppTheme.sheetTextSecondary,
                                  nbrTilesRow: 4,
                                  labelTextStyle: const TextStyle(
                                    fontFamily: _kFontFamily,
                                    color: AppTheme.onSurfaceDark,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  selectedTileDecoration: BoxDecoration(
                                    color: AppTheme.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: AppTheme.primary,
                                      width: 2.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.primary.withValues(
                                          alpha: 0.2,
                                        ),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  unselectedTileDecoration: BoxDecoration(
                                    color: AppTheme.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: AppTheme.accentPurple.withValues(
                                        alpha: 0.25,
                                      ),
                                      width: 1,
                                    ),
                                  ),
                                  boxDecoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  tileMargin: const EdgeInsets.all(6.0),
                                  tilePadding: const EdgeInsets.all(6.0),
                                ),
                              ),
                            ),
                            // Left arrow button to switch to previous customization category
                            Positioned(
                              top: 4,
                              left: 6,
                              child: _NavArrowButton(
                                icon: Icons.chevron_left_rounded,
                                onTap: () => _switchCategory(false),
                              ),
                            ),
                            // Right arrow button to switch to next customization category
                            Positioned(
                              top: 4,
                              right: 6,
                              child: _NavArrowButton(
                                icon: Icons.chevron_right_rounded,
                                onTap: () => _switchCategory(true),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NavArrowButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _NavArrowButton({required this.icon, required this.onTap});

  @override
  State<_NavArrowButton> createState() => _NavArrowButtonState();
}

class _NavArrowButtonState extends State<_NavArrowButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        width: 48,
        height: 48,
        transform: _pressed
            ? Matrix4.translationValues(0, 2, 0)
            : Matrix4.identity(),
        decoration: BoxDecoration(
          color: _pressed ? const Color(0xFFF0EBFF) : AppTheme.white,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(widget.icon, color: AppTheme.primary, size: 30),
      ),
    );
  }
}

/// Solid white card housing the avatar customiser — a distinct floating
/// surface with a soft violet-tinted border and elevation shadow. The
/// generous inset between the border and the customiser content is
/// deliberate: the customiser's own background is white too, so without a
/// visible frame margin the rounded corners have no color contrast to read
/// against and disappear visually even though they're still geometrically
/// clipped.
class _GlassCard extends StatelessWidget {
  final double height;
  final Widget child;

  const _GlassCard({required this.height, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(
          color: AppTheme.accentPurple.withValues(alpha: 0.45),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.dropShadow,
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: child,
      ),
    );
  }
}

// ── Step 1: Basic Info ───────────────────────────────────────────────────────

class _BasicInfoStep extends StatelessWidget {
  final AvatarMakerController avatarController;
  final TextEditingController nameCtrl;
  final TextEditingController idCtrl;
  final String mascotMessage;
  final VoidCallback onTextChanged;

  const _BasicInfoStep({
    required this.avatarController,
    required this.nameCtrl,
    required this.idCtrl,
    required this.mascotMessage,
    required this.onTextChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24.0,
        0,
        24.0,
        MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          _StepHeader(
            illustration: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.accentPurple.withValues(alpha: 0.6),
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accentPurple.withValues(alpha: 0.2),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: FramedAvatar(
                size: 108,
                backgroundColor: AppTheme.white,
                controller: avatarController,
              ),
            ),
            headline: 'Basic Info',
            body: mascotMessage,
          ),
          const SizedBox(height: 28),
          _OnboardingTextField(
            controller: nameCtrl,
            label: 'Full Name',
            hint: 'e.g. Arjun Sharma',
            onChanged: (_) => onTextChanged(),
            textCapitalization: TextCapitalization.words,
            // Extra bottom scroll padding so focusing this field also keeps
            // the BITS ID field below it in view above the keyboard.
            scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          ),
          const SizedBox(height: 16),
          _OnboardingTextField(
            controller: idCtrl,
            label: 'BITS ID',
            hint: 'e.g. 2023A7PSXXXXH',
            onChanged: (_) => onTextChanged(),
            textCapitalization: TextCapitalization.none,
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

// ── Step 2: Institution ──────────────────────────────────────────────────────

class _InstitutionStep extends StatelessWidget {
  final String campusName;
  final String campusLocation;
  final String campusDomain;
  final String mascotMessage;
  final VoidCallback onChangeCampus;

  const _InstitutionStep({
    required this.campusName,
    required this.campusLocation,
    required this.campusDomain,
    required this.mascotMessage,
    required this.onChangeCampus,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          _StepHeader(
            illustration: const _IconIllustration(icon: Icons.business_rounded),
            headline: 'Confirm your campus',
            body: mascotMessage,
          ),
          const SizedBox(height: 28),
          _CampusSelectField(
            campusName: campusName,
            campusLocation: campusLocation,
            campusDomain: campusDomain,
            onTap: onChangeCampus,
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

/// Dropdown-styled tappable field showing the detected/selected campus —
/// opens the campus picker sheet on tap.
class _CampusSelectField extends StatelessWidget {
  final String campusName;
  final String campusLocation;
  final String campusDomain;
  final VoidCallback onTap;

  const _CampusSelectField({
    required this.campusName,
    required this.campusLocation,
    required this.campusDomain,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Campus',
          style: TextStyle(
            fontFamily: _kFontFamily,
            color: AppTheme.textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppTheme.accentPurple.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '$campusName, $campusLocation',
                    style: const TextStyle(
                      fontFamily: _kFontFamily,
                      color: AppTheme.onBackground,
                      fontSize: 15,
                    ),
                  ),
                ),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppTheme.textMuted,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: AppTheme.accentPurple.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.accentPurple.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            campusDomain,
            style: const TextStyle(
              fontFamily: _kFontFamily,
              color: AppTheme.accentPurple,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Step 3: Academic Details ─────────────────────────────────────────────────

class _AcademicStep extends StatelessWidget {
  final String? branch;
  final bool isDualDegree;
  final String? dualBranch;
  final int? currentYear;
  final int? currentSemester;
  final String mascotMessage;

  final ValueChanged<String?> onBranchChanged;
  final ValueChanged<bool> onDualToggle;
  final ValueChanged<String?> onDualBranchChanged;
  final ValueChanged<int?> onYearChanged;
  final ValueChanged<int?> onSemesterChanged;

  const _AcademicStep({
    required this.branch,
    required this.isDualDegree,
    required this.dualBranch,
    required this.currentYear,
    required this.currentSemester,
    required this.mascotMessage,
    required this.onBranchChanged,
    required this.onDualToggle,
    required this.onDualBranchChanged,
    required this.onYearChanged,
    required this.onSemesterChanged,
  });

  static const _branches = [
    'Computer Science',
    'Electrical & Electronics',
    'Mechanical',
    'Chemical',
    'Civil',
    'Economics',
    'Mathematics',
    'Physics',
    'Biology',
  ];

  static const _dualBranches = [
    'Economics',
    'Mathematics',
    'Physics',
    'Chemistry',
    'Biology',
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          _StepHeader(
            illustration: const _IconIllustration(icon: Icons.school_rounded),
            headline: 'Academic Details',
            body: mascotMessage,
          ),
          const SizedBox(height: 28),

          _OnboardingDropdown<String>(
            label: 'Branch / Programme',
            value: branch,
            items: _branches,
            onChanged: onBranchChanged,
          ),
          const SizedBox(height: 16),

          // Dual-degree toggle — flips to a light card once enabled, to
          // match the light MSc-branch dropdown that reveals beneath it.
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDualDegree ? AppTheme.sheetBackground : AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDualDegree
                    ? AppTheme.accentPurple.withValues(alpha: 0.5)
                    : AppTheme.white.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              children: [
                Transform.scale(
                  scale: 0.88,
                  child: Switch(
                    value: isDualDegree,
                    activeTrackColor: AppTheme.accentPurpleDark.withValues(
                      alpha: 0.5,
                    ),
                    activeThumbColor: AppTheme.accentPurpleDark,
                    onChanged: onDualToggle,
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dual Degree',
                      style: TextStyle(
                        fontFamily: _kFontFamily,
                        color: isDualDegree
                            ? AppTheme.onSurfaceDark
                            : AppTheme.onBackground,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      'I have an MSc programme',
                      style: TextStyle(
                        fontFamily: _kFontFamily,
                        color: isDualDegree
                            ? AppTheme.sheetTextSecondary
                            : AppTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Dual branch dropdown (animated reveal)
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            child: isDualDegree
                ? Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: _OnboardingDropdown<String>(
                      label: 'MSc Branch',
                      value: dualBranch,
                      items: _dualBranches,
                      onChanged: onDualBranchChanged,
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _OnboardingDropdown<int>(
                  label: 'Year',
                  value: currentYear,
                  items: const [1, 2, 3, 4, 5],
                  onChanged: onYearChanged,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _OnboardingDropdown<int>(
                  label: 'Semester',
                  value: currentSemester,
                  items: const [1, 2],
                  onChanged: onSemesterChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

// ── Step 4: Study Capacity ────────────────────────────────────────────────────

class _CapacityStep extends StatelessWidget {
  final String? selected;
  final String mascotMessage;
  final ValueChanged<String> onSelect;
  final VoidCallback onConfirm;

  const _CapacityStep({
    required this.selected,
    required this.mascotMessage,
    required this.onSelect,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final illustrationIcon = _kCapacityOptions
        .firstWhere(
          (o) => o.value == selected,
          orElse: () => _kCapacityOptions[1],
        )
        .icon;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          _StepHeader(
            illustration: _IconIllustration(icon: illustrationIcon),
            headline: 'How busy are you\nthis semester?',
            body: mascotMessage,
          ),
          const SizedBox(height: 28),
          _CapacityCarousel(
            selected: selected,
            onSelect: onSelect,
            onConfirm: onConfirm,
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

/// [PageScrollPhysics] variant that lets a fast fling carry through several
/// cards before settling. Stock [PageScrollPhysics] always nudges the
/// release point by a fixed +/-0.5 page before rounding, so even a hard
/// flick only ever advances one page — this instead estimates how far a
/// friction-based ballistic scroll of the release velocity would travel
/// (via [FrictionSimulation.finalX]) and lands on the nearest whole page
/// along that distance. A slow drag/gentle fling falls back to the same
/// minimum single-page nudge as stock, so it still feels like a normal snap.
class _MultiFlingPageScrollPhysics extends ScrollPhysics {
  const _MultiFlingPageScrollPhysics({super.parent});

  // Higher drag = a given velocity travels less distance before settling.
  // Tuned so a firm flick carries 2-4 cards and only a very hard flick
  // reaches the cap below.
  static const double _kFlingDrag = 0.03;
  // Caps how many pages a single fling can commit to, however hard the
  // flick, so the carousel never jumps somewhere disorienting in one go.
  static const double _kMaxFlingPages = 6.0;

  @override
  _MultiFlingPageScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _MultiFlingPageScrollPhysics(parent: buildParent(ancestor));
  }

  // ScrollPhysics' default spring (mass:0.5, stiffness:100, ratio:1.1) is
  // tuned for stock PageScrollPhysics' short single-page nudges. Its decay
  // to the (very tight, sub-pixel) default tolerance is roughly logarithmic
  // in distance, so reusing it here — where a hard fling travels several
  // page-widths — measured at ~930-980ms to settle. ratio:1.0 is critical
  // damping: the fastest decay a spring can have while still never
  // overshooting the target (ratio>1 is overdamped/slower, ratio<1 would
  // bounce past it). Empirically, stiffness:1200/ratio:1.0 settles a slow
  // drag/medium swipe/hard fling in ~190-240ms with zero overshoot and zero
  // residual, vs. ~290-390ms at stiffness:700/ratio:1.1 and ~720-980ms at
  // the framework default. This is also why the post-settle highlight fade
  // (`_settled`, see _CapacityCarouselState) used to feel slow to appear:
  // it was waiting on this same spring.
  @override
  SpringDescription get spring => SpringDescription.withDampingRatio(
    mass: 0.5,
    stiffness: 1200,
    ratio: 1.0,
  );

  double _getPage(ScrollMetrics position) {
    if (position is PageMetrics) {
      return position.page ?? position.pixels / position.viewportDimension;
    }
    return position.pixels / position.viewportDimension;
  }

  double _getPixels(ScrollMetrics position, double page) {
    // Equivalent to the framework's private `_PagePosition.getPixelsFromPage`
    // for a viewportFraction <= 1 (our case): the `_initialPageOffset` term
    // that formula adds is always zero in that range.
    final double viewportFraction = position is PageMetrics
        ? position.viewportFraction
        : 1.0;
    return page * position.viewportDimension * viewportFraction;
  }

  double _getTargetPixels(
    ScrollMetrics position,
    Tolerance tolerance,
    double velocity,
  ) {
    double page = _getPage(position);
    if (velocity.abs() > tolerance.velocity) {
      final double pixelsPerPage = position is PageMetrics
          ? position.viewportDimension * position.viewportFraction
          : position.viewportDimension;
      final double flingDistance = FrictionSimulation(
        _kFlingDrag,
        0,
        velocity,
      ).finalX;
      final double flingPages = (flingDistance / pixelsPerPage).clamp(
        -_kMaxFlingPages,
        _kMaxFlingPages,
      );
      // A release barely over the tolerance still commits to at least one
      // page — matches stock PageScrollPhysics' minimum nudge.
      page += flingPages.abs() > 0.5 ? flingPages : 0.5 * velocity.sign;
    }
    return _getPixels(position, page.roundToDouble());
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    // Out of range and not headed back in range — defer to the parent
    // physics chain (overscroll bounce, etc.), same as stock PageScrollPhysics.
    if ((velocity <= 0.0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0.0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }
    final Tolerance tolerance = toleranceFor(position);
    final double target = _getTargetPixels(position, tolerance, velocity);
    if (target != position.pixels) {
      return ScrollSpringSimulation(
        spring,
        position.pixels,
        target,
        velocity,
        tolerance: tolerance,
      );
    }
    return null;
  }

  @override
  bool get allowImplicitScrolling => true;
}

/// Looping card carousel for study pace — swiping (or tapping a peeking
/// neighbour) to centre a card selects it. `PageView.builder` is given no
/// `itemCount` so it scrolls infinitely; each absolute page maps back to one
/// of the three options via `page % _kOptionCount`. The controller starts
/// deep into that infinite range (a multiple of 3, offset by the currently
/// selected option if any) so the user can swipe backwards from the first
/// card without ever hitting an edge.
class _CapacityCarousel extends StatefulWidget {
  final String? selected;
  final ValueChanged<String> onSelect;
  final VoidCallback onConfirm;

  const _CapacityCarousel({
    required this.selected,
    required this.onSelect,
    required this.onConfirm,
  });

  @override
  State<_CapacityCarousel> createState() => _CapacityCarouselState();
}

class _CapacityCarouselState extends State<_CapacityCarousel> {
  static final _kOptionCount = _kCapacityOptions.length;
  static const _kBasePage = 3000; // multiple of _kOptionCount

  // ── Tunables ────────────────────────────────────────────────────────────
  // Lower fraction = more of each neighbour peeks in at the screen edges.
  static const double _kViewportFraction = 0.74;
  // Centre-card vs. resting-neighbour scale — the gap between these is what
  // reads as depth as a card slides toward/away from centre. Centre is
  // scaled past 1.0 so it visibly pops out of the strip; PageView below
  // uses clipBehavior: Clip.none so that overscale isn't clipped by the
  // fixed-height viewport.
  static const double _kCenterScale = 1.08;
  static const double _kNeighborScale = 0.86;
  // Paired opacity falloff, kept subtle so it reads as depth, not a glitch.
  static const double _kCenterOpacity = 1.0;
  static const double _kNeighborOpacity = 0.65;

  late final PageController _controller;
  late int _currentPage;

  // Gates the centre card's accent/selected treatment: only true once
  // scrolling has fully come to rest, so the highlight doesn't flicker
  // between cards mid-fling. Driven by ScrollNotification, not a debounce
  // timer, so it can't fire early on a slow pass through several cards.
  bool _settled = true;

  @override
  void initState() {
    super.initState();
    final selectedIndex = widget.selected == null
        ? 0
        : _kCapacityOptions
              .indexWhere((o) => o.value == widget.selected)
              .clamp(0, _kOptionCount - 1);
    _currentPage = _kBasePage + selectedIndex;
    _controller = PageController(
      viewportFraction: _kViewportFraction,
      initialPage: _currentPage,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handlePageChanged(int page) {
    setState(() => _currentPage = page);
    widget.onSelect(_kCapacityOptions[page % _kOptionCount].value);
  }

  void _goToPage(int page) {
    _controller.animateToPage(
      page,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification && _settled) {
      setState(() => _settled = false);
    } else if (notification is ScrollEndNotification && !_settled) {
      setState(() => _settled = true);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 336,
          child: NotificationListener<ScrollNotification>(
            onNotification: _handleScrollNotification,
            child: PageView.builder(
              controller: _controller,
              physics: const _MultiFlingPageScrollPhysics(),
              // Framework quirk: whenever pageSnapping is true, PageView always
              // wraps `physics` inside a *fresh* stock PageScrollPhysics via
              // `_kPagePhysics.applyTo(physics)` (see page_view.dart), which
              // becomes the effective physics and permanently shadows ours —
              // its own createBallisticSimulation never delegates to `.parent`
              // except when out of scroll range, so our multi-fling logic is
              // never reached. Must stay false, or the carousel silently goes
              // back to single-page nudges. _MultiFlingPageScrollPhysics
              // implements the snapping itself (rounds to the nearest page and
              // settles there via ScrollSpringSimulation), so nothing is lost.
              pageSnapping: false,
              // The centre card scales past 1.0 (see _kCenterScale); without
              // this, the fixed-height viewport would clip its top/bottom.
              clipBehavior: Clip.none,
              onPageChanged: _handlePageChanged,
              itemBuilder: (context, page) {
                final option = _kCapacityOptions[page % _kOptionCount];
                final isCentered = page == _currentPage;
                return AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final rawPage = _controller.hasClients
                        ? (_controller.page ?? _currentPage.toDouble())
                        : _currentPage.toDouble();
                    final distance = (rawPage - page).abs().clamp(0.0, 1.0);
                    final scale =
                        _kCenterScale -
                        (distance * (_kCenterScale - _kNeighborScale));
                    final opacity =
                        _kCenterOpacity -
                        (distance * (_kCenterOpacity - _kNeighborOpacity));
                    return Transform.scale(
                      scale: scale,
                      child: Opacity(opacity: opacity, child: child),
                    );
                  },
                  child: GestureDetector(
                    onTap: () {
                      if (page != _currentPage) _goToPage(page);
                    },
                    child: _CapacityCard(
                      option: option,
                      isSelected: _settled && option.value == widget.selected,
                      // Centred card's pill commits the pick and advances
                      // (replaces the removed footer Continue button); a
                      // peeking card's pill just centres it, same as tapping
                      // the card body.
                      onSelectTap: () {
                        if (isCentered) {
                          if (widget.selected != option.value) {
                            widget.onSelect(option.value);
                          }
                          widget.onConfirm();
                        } else {
                          _goToPage(page);
                        }
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Single pace card shown inside [_CapacityCarousel]. Only reflects the
/// committed `selected` value (not merely "currently centred") so the violet
/// accent only appears once the user has actually picked a pace — matching
/// the dropdown's previous "nothing selected until chosen" behaviour.
class _CapacityCard extends StatelessWidget {
  final _CapacityOption option;
  final bool isSelected;
  final VoidCallback onSelectTap;

  const _CapacityCard({
    required this.option,
    required this.isSelected,
    required this.onSelectTap,
  });

  static const _cardRadius = 32.0;
  // Zeroed out so adjacent cards run edge-to-edge as one continuous strip
  // while scrolling, instead of visibly separated tiles with a gap between
  // them; the neighbour's reduced scale/opacity is what still reads as
  // depth, not this margin. The lowered PageView viewportFraction (not this
  // value) is what produces a real peek of the neighbouring card.
  static const _cardHorizontalMargin = 0.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        _cardHorizontalMargin,
        18,
        _cardHorizontalMargin,
        0,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accentPurple : AppTheme.surface,
          borderRadius: BorderRadius.circular(_cardRadius),
          border: isSelected
              ? null
              : Border.all(color: AppTheme.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? AppTheme.white.withValues(alpha: 0.18)
                        : AppTheme.surfaceLight,
                  ),
                  child: Icon(
                    option.icon,
                    color: isSelected ? AppTheme.onPrimary : AppTheme.textMuted,
                    size: 30,
                  ),
                ),
                if (isSelected)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.accentPurpleDark,
                        border: Border.all(
                          color: AppTheme.accentPurple,
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: AppTheme.onPrimary,
                        size: 13,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              option.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: _kFontFamily,
                color: isSelected ? AppTheme.onPrimary : AppTheme.onBackground,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.white.withValues(alpha: 0.16)
                    : AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                option.hours,
                style: TextStyle(
                  fontFamily: _kFontFamily,
                  color: isSelected ? AppTheme.onPrimary : AppTheme.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              option.description,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: _kFontFamily,
                color: isSelected
                    ? AppTheme.onPrimary.withValues(alpha: 0.85)
                    : AppTheme.textMuted,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            GestureDetector(
              onTap: onSelectTap,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.background
                      : AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isSelected) ...[
                      const Icon(
                        Icons.check_rounded,
                        color: AppTheme.accentPurple,
                        size: 15,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      isSelected ? 'Selected' : 'Select',
                      style: TextStyle(
                        fontFamily: _kFontFamily,
                        color: isSelected ? AppTheme.white : AppTheme.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Step 5: Endgame goal (single-select) ─────────────────────────────────────

class _EndgameStep extends StatelessWidget {
  final String mascotMessage;
  final String? selected;
  final ValueChanged<String> onSelect;

  const _EndgameStep({
    required this.mascotMessage,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          _StepHeader(
            illustration: const _IconIllustration(icon: Icons.flag_rounded),
            headline: "What's your endgame?",
            body: mascotMessage,
          ),
          const SizedBox(height: 28),
          _OnboardingDropdown<String>(
            label: 'Endgame',
            value: selected,
            items: _kEndgameOptions,
            onChanged: (v) {
              if (v != null) onSelect(v);
            },
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

// ── Step 6: Career interests (multi-select) ──────────────────────────────────

class _InterestsStep extends StatelessWidget {
  final String mascotMessage;
  final List<String> selected;
  final ValueChanged<String> onToggle;

  const _InterestsStep({
    required this.mascotMessage,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          _StepHeader(
            illustration: const _IconIllustration(icon: Icons.explore_rounded),
            headline: 'Career interests',
            body: mascotMessage,
          ),
          const SizedBox(height: 28),
          _InterestTileGrid(
            options: _kCareerInterests,
            selected: selected,
            onToggle: onToggle,
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

/// Grid of circular icon tiles with a check badge on selected items.
class _InterestTileGrid extends StatelessWidget {
  final List<String> options;
  final List<String> selected;
  final ValueChanged<String> onToggle;

  const _InterestTileGrid({
    required this.options,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: options.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 20,
        crossAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemBuilder: (context, i) {
        final option = options[i];
        final isSelected = selected.contains(option);
        return _InterestTile(
          label: option,
          icon: _kCareerInterestIcons[option] ?? Icons.circle_outlined,
          isSelected: isSelected,
          onTap: () => onToggle(option),
        );
      },
    );
  }
}

class _InterestTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _InterestTile({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? AppTheme.accentPurple : AppTheme.surface,
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.accentPurple
                        : AppTheme.white.withValues(alpha: 0.08),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  icon,
                  color: isSelected ? AppTheme.onPrimary : AppTheme.textMuted,
                  size: 28,
                ),
              ),
              if (isSelected)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.accentPurple,
                      border: Border.all(color: AppTheme.background, width: 2),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: AppTheme.onPrimary,
                      size: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: _kFontFamily,
              color: isSelected ? AppTheme.onBackground : AppTheme.textMuted,
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step 7: Prep style (single-select) ───────────────────────────────────────

class _PrepStyleStep extends StatelessWidget {
  final String mascotMessage;
  final String? selected;
  final ValueChanged<String> onSelect;

  const _PrepStyleStep({
    required this.mascotMessage,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          _StepHeader(
            illustration: const _IconIllustration(icon: Icons.schedule_rounded),
            headline: 'Prep style',
            body: mascotMessage,
          ),
          const SizedBox(height: 28),
          _OnboardingDropdown<String>(
            label: 'Prep style',
            value: selected,
            items: _kPrepStyles,
            onChanged: (v) {
              if (v != null) onSelect(v);
            },
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared Form Widgets
// ─────────────────────────────────────────────────────────────────────────────

class _OnboardingTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final ValueChanged<String>? onChanged;
  final TextCapitalization textCapitalization;
  final EdgeInsets scrollPadding;

  const _OnboardingTextField({
    required this.controller,
    required this.label,
    required this.hint,
    this.onChanged,
    required this.textCapitalization,
    this.scrollPadding = const EdgeInsets.all(20.0),
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: _kFontFamily,
            color: AppTheme.textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          textCapitalization: textCapitalization,
          onChanged: onChanged,
          scrollPadding: scrollPadding,
          style: const TextStyle(
            fontFamily: _kFontFamily,
            color: AppTheme.onBackground,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              fontFamily: _kFontFamily,
              color: AppTheme.textMuted,
            ),
            filled: true,
            fillColor: AppTheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: AppTheme.white.withValues(alpha: 0.08),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: AppTheme.accentPurple,
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }
}

class _OnboardingDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<T> items;
  final ValueChanged<T?> onChanged;

  const _OnboardingDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: _kFontFamily,
            color: AppTheme.textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            border: Border.all(
              color: value != null
                  ? AppTheme.accentPurple.withValues(alpha: 0.4)
                  : AppTheme.white.withValues(alpha: 0.08),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              dropdownColor: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(AppTheme.radiusXl),
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppTheme.textMuted,
              ),
              style: const TextStyle(
                fontFamily: _kFontFamily,
                color: AppTheme.onBackground,
                fontSize: 15,
              ),
              hint: const Text(
                'Select one',
                style: TextStyle(
                  fontFamily: _kFontFamily,
                  color: AppTheme.textMuted,
                ),
              ),
              onChanged: onChanged,
              items: items
                  .map(
                    (item) => DropdownMenuItem<T>(
                      value: item,
                      child: Text(item.toString()),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }
}
