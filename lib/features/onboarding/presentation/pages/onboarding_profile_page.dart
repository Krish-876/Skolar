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
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:Skolar/core/routing/app_routes.dart';
import 'package:Skolar/core/theme/app_theme.dart';
import 'package:Skolar/features/onboarding/presentation/providers/onboarding_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

const _kTotalSteps = 7;

const _kPrimary = Color(0xFF8C38E5);
const _kSurface = Color(0xFF1C1C1E);
const _kBg = Color(0xFF16161A);
const _kSpeechBubble = Color(0xFF2A0D55);

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

const _kPrepStyles = [
  'Steady all semester',
  'Cram near exams',
  'Depends on subject',
  'Not sure',
];

// ─────────────────────────────────────────────────────────────────────────────
// Capacity card data model
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
// OnboardingProfilePage — entry point, hosts the full 7-step flow
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
  bool _showSuccess = false;

  // ── Progress bar fill animation ───────────────────────────────────────────
  late AnimationController _progressCtrl;
  late Animation<double> _progressFill; // 0→1 for the current segment

  // ── Step 0 : Profile ──────────────────────────────────────────────────────
  final _nameCtrl = TextEditingController();
  final _idCtrl = TextEditingController();
  bool _avatarConfirmed = false;
  late final AvatarMakerController _avatarMakerController;

  // ── Step 1 : Institution ──────────────────────────────────────────────────
  String _campusName = 'BITS Pilani';
  String _campusLocation = 'Pilani Campus';
  String _campusDomain = '@pilani.bits-pilani.ac.in';

  // ── Step 2 : Academic details ─────────────────────────────────────────────
  String? _branch;
  bool _isDualDegree = false;
  String? _dualBranch;
  int? _currentYear;
  int? _currentSemester;

  // ── Step 3 : Study capacity ───────────────────────────────────────────────
  String? _studyCapacity;

  @override
  void initState() {
    super.initState();
    _avatarMakerController = NonPersistentAvatarMakerController();

    // Step entrance animation
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
    HapticFeedback.lightImpact();

    // Step-0 sub-stage: confirm avatar before showing name fields
    if (_step == 0 && !_avatarConfirmed) {
      setState(() => _avatarConfirmed = true);
      return;
    }

    _persistCurrentStep();

    if (_step < _kTotalSteps - 1) {
      setState(() => _step++);
      _playStepEntrance();
    } else {
      await ref.read(onboardingProvider.notifier).complete();
      setState(() => _showSuccess = true);
      Future.delayed(const Duration(milliseconds: 3200), () {
        if (mounted) context.go(AppRoutes.dashboard);
      });
    }
  }

  void _back() {
    HapticFeedback.selectionClick();

    if (_step == 0 && _avatarConfirmed) {
      setState(() => _avatarConfirmed = false);
      return;
    }

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
        n.setName(_nameCtrl.text.trim());
        n.setId(_idCtrl.text.trim());
      case 1:
        n.setCampus(_campusLocation.split(' ').first.toLowerCase());
      case 2:
        if (_branch != null) n.setBranch(_branch!);
        n.setDualBranch(_dualBranch);
        if (_currentYear != null) n.setCurrentYear(_currentYear!);
        if (_currentSemester != null) n.setCurrentSemester(_currentSemester!);
      case 3:
        if (_studyCapacity != null) n.setStudyCapacity(_studyCapacity!);
    }
  }

  // ── Can-advance gate ──────────────────────────────────────────────────────
  bool _canAdvance() {
    final s = ref.watch(onboardingProvider);
    switch (_step) {
      case 0:
        if (!_avatarConfirmed) return true; // "Confirm Avatar" always enabled
        return _nameCtrl.text.trim().isNotEmpty &&
            _idCtrl.text.trim().isNotEmpty;
      case 1:
        return true;
      case 2:
        return _branch != null &&
            _currentYear != null &&
            _currentSemester != null &&
            (!_isDualDegree || _dualBranch != null);
      case 3:
        return _studyCapacity != null;
      case 4:
        return s.endgame != null;
      case 5:
        return s.careerInterests.isNotEmpty;
      case 6:
        return s.prepStyle != null;
      default:
        return false;
    }
  }

  String _buttonLabel() {
    if (_step == 0 && !_avatarConfirmed) return 'Confirm Avatar';
    if (_step == 1) return 'Yes, continue →';
    if (_step == _kTotalSteps - 1) return 'Save Preference →';
    return 'Continue →';
  }

  String _mascotMessage() {
    switch (_step) {
      case 0:
        return _avatarConfirmed
            ? "Looking good! Now, what should I call you?"
            : "Let's create your digital twin! Customise your avatar below.";
      case 1:
        return "I've automatically detected your institution based on your BITS email. Is this the campus you're currently attending?";
      case 2:
        return "Tell me about your academic setup — I'll personalise your study plan around it.";
      case 3:
        return "Nova will curate your focus list based on your availability. You can change this anytime in settings.";
      case 4:
        return "What's your endgame right now? Nova will use this to balance your academic vs career focus.";
      case 5:
        return "Select all the areas that interest you — I'll weight resources accordingly.";
      case 6:
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
    if (_showSuccess) {
      return Scaffold(
        backgroundColor: _kBg,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.network(
                'https://lottie.host/f35a38c5-c434-4dee-9979-6144e32d6446/ixzaLS3V22.json',
                width: 300,
                height: 300,
                repeat: false,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 24),
              Text(
                "You're all set!",
                style: GoogleFonts.googleSans(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Taking you to your dashboard...",
                style: GoogleFonts.googleSans(
                  color: Colors.white54,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final canAdvance = _canAdvance();
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(step: _step, total: _kTotalSteps, onBack: _back),
            _ProgressBar(
              step: _step,
              total: _kTotalSteps,
              fillAnim: _progressFill,
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
                  key: ValueKey('step_${_step}_$_avatarConfirmed'),
                  child: _buildCurrentStep(),
                ),
              ),
            ),
            _FooterButton(
              label: _buttonLabel(),
              enabled: canAdvance,
              onTap: _advance,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_step) {
      case 0:
        return _ProfileStep(
          avatarConfirmed: _avatarConfirmed,
          avatarController: _avatarMakerController,
          nameCtrl: _nameCtrl,
          idCtrl: _idCtrl,
          mascotMessage: _mascotMessage(),
          onTextChanged: () => setState(() {}),
        );
      case 1:
        return _InstitutionStep(
          campusName: _campusName,
          campusLocation: _campusLocation,
          campusDomain: _campusDomain,
          mascotMessage: _mascotMessage(),
          onChangeCampus: _changeCampus,
        );
      case 2:
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
      case 3:
        return _CapacityStep(
          selected: _studyCapacity,
          mascotMessage: _mascotMessage(),
          onSelect: (v) => setState(() => _studyCapacity = v),
        );
      case 4:
        return _QuestionStep(
          mascotMessage: _mascotMessage(),
          options: _kEndgameOptions,
          isMultiSelect: false,
          selectedValue: ref.watch(onboardingProvider).endgame,
          onSelect: (val) {
            ref.read(onboardingProvider.notifier).setEndgame(val);
            Future.delayed(const Duration(milliseconds: 280), _advance);
          },
        );
      case 5:
        return _QuestionStep(
          mascotMessage: _mascotMessage(),
          options: _kCareerInterests,
          isMultiSelect: true,
          selectedValues: ref.watch(onboardingProvider).careerInterests,
          onSelect: (val) =>
              ref.read(onboardingProvider.notifier).toggleCareerInterest(val),
        );
      case 6:
        return _QuestionStep(
          mascotMessage: _mascotMessage(),
          options: _kPrepStyles,
          isMultiSelect: false,
          selectedValue: ref.watch(onboardingProvider).prepStyle,
          onSelect: (val) {
            ref.read(onboardingProvider.notifier).setPrepStyle(val);
            Future.delayed(const Duration(milliseconds: 280), _advance);
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
      backgroundColor: const Color(0xFF1E1E22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Choose Campus',
            style: GoogleFonts.googleSans(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
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
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _campusTile(
    BuildContext ctx,
    String name,
    String location,
    String domain,
  ) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _kPrimary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.business_rounded, color: _kPrimary, size: 18),
      ),
      title: Text(
        '$name, $location',
        style: GoogleFonts.googleSans(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        domain,
        style: GoogleFonts.googleSans(color: Colors.white54, fontSize: 12),
      ),
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

class _TopBar extends StatelessWidget {
  final int step;
  final int total;
  final VoidCallback onBack;

  const _TopBar({
    required this.step,
    required this.total,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.chevron_left,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ONBOARDING',
                style: GoogleFonts.googleSans(
                  color: _kPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.6,
                ),
              ),
              Text(
                'STEP ${step + 1} OF $total',
                style: GoogleFonts.googleSans(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.help_outline,
              color: Colors.white38,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final int step;
  final int total;
  final Animation<double> fillAnim;

  const _ProgressBar({
    required this.step,
    required this.total,
    required this.fillAnim,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: List.generate(total, (i) {
          final isPast = i < step;
          final isCurrent = i == step;
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: i < total - 1 ? 5 : 0),
              height: 3,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(2),
              ),
              child: isPast
                  ? Container(color: _kPrimary)
                  : isCurrent
                  ? AnimatedBuilder(
                      animation: fillAnim,
                      builder: (_, _) => FractionallySizedBox(
                        widthFactor: fillAnim.value,
                        alignment: Alignment.centerLeft,
                        child: Container(color: _kPrimary),
                      ),
                    )
                  : null,
            ),
          );
        }),
      ),
    );
  }
}

/// Mascot avatar + animated speech-bubble header used on every step.
class _MascotHeader extends StatelessWidget {
  final String message;

  const _MascotHeader({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar + online dot
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _kPrimary.withValues(alpha: 0.7),
                    width: 2,
                  ),
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/mascot.jpeg',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: const Color(0xFF34C759),
                    shape: BoxShape.circle,
                    border: Border.all(color: _kBg, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          // Speech bubble
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: _kSpeechBubble,
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Text(
                message,
                style: GoogleFonts.googleSans(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _FooterButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.4,
        duration: const Duration(milliseconds: 200),
        child: IgnorePointer(
          ignoring: !enabled,
          child: GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 17),
              decoration: BoxDecoration(
                gradient: enabled
                    ? const LinearGradient(
                        colors: [Color(0xFF9B4DFF), Color(0xFF7428D8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: enabled ? null : _kSurface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: enabled
                    ? [
                        BoxShadow(
                          color: _kPrimary.withValues(alpha: 0.38),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : [],
              ),
              alignment: Alignment.center,
              child: Text(
                label,
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step Widgets
// ─────────────────────────────────────────────────────────────────────────────

// ── Step 0: Profile ──────────────────────────────────────────────────────────

class _ProfileStep extends StatelessWidget {
  final bool avatarConfirmed;
  final AvatarMakerController avatarController;
  final TextEditingController nameCtrl;
  final TextEditingController idCtrl;
  final String mascotMessage;
  final VoidCallback onTextChanged;

  const _ProfileStep({
    required this.avatarConfirmed,
    required this.avatarController,
    required this.nameCtrl,
    required this.idCtrl,
    required this.mascotMessage,
    required this.onTextChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MascotHeader(message: mascotMessage),
          const SizedBox(height: 24),
          // Avatar preview — always visible
          Center(
            child: CircleAvatar(
              radius: 60,
              backgroundColor: AppTheme.surface,
              child: ClipOval(
                child: AvatarMakerAvatar(
                  radius: 60,
                  backgroundColor: Colors.transparent,
                  controller: avatarController,
                ),
              ),
            ),
          ),
          // Animated switch between customiser and input fields
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 460),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, anim) => SizeTransition(
              sizeFactor: anim,
              alignment: AlignmentDirectional.topCenter,
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: !avatarConfirmed
                ? Column(
                    key: const ValueKey('customiser'),
                    children: [
                      const SizedBox(height: 24),
                      Container(
                        height: 360,
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4EBFF),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: AvatarMakerCustomizer(
                          controller: avatarController,
                          theme: AvatarMakerThemeData(
                            primaryBgColor: Colors.transparent,
                            secondaryBgColor: Colors.transparent,
                            iconColor: Colors.black54,
                            selectedIconColor: _kPrimary,
                            unselectedIconColor: Colors.black38,
                            labelTextStyle: GoogleFonts.googleSans(
                              color: Colors.black87,
                              fontWeight: FontWeight.bold,
                            ),
                            selectedTileDecoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _kPrimary, width: 3.0),
                            ),
                            unselectedTileDecoration: const BoxDecoration(),
                            boxDecoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            tileMargin: const EdgeInsets.all(4.0),
                            tilePadding: const EdgeInsets.all(4.0),
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    key: const ValueKey('inputs'),
                    children: [
                      const SizedBox(height: 32),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Basic Info',
                              style: GoogleFonts.googleSans(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 20),
                            _OnboardingTextField(
                              controller: nameCtrl,
                              label: 'Full Name',
                              hint: 'e.g. Arjun Sharma',
                              onChanged: (_) => onTextChanged(),
                            ),
                            const SizedBox(height: 16),
                            _OnboardingTextField(
                              controller: idCtrl,
                              label: 'BITS ID',
                              hint: 'e.g. 2023A7PSXXXXH',
                              onChanged: (_) => onTextChanged(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

// ── Step 1: Institution ──────────────────────────────────────────────────────

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
        children: [
          _MascotHeader(message: mascotMessage),
          const SizedBox(height: 28),

          // ── Institution card ───────────────────────────────────────────
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: _kSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              children: [
                // Banner
                Container(
                  height: 130,
                  decoration: const BoxDecoration(
                    color: Color(0xFF200A42),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Decorative ghost icons
                      Positioned(
                        left: -24,
                        bottom: -16,
                        child: Icon(
                          Icons.business_rounded,
                          color: Colors.white.withValues(alpha: 0.05),
                          size: 110,
                        ),
                      ),
                      Positioned(
                        right: -14,
                        bottom: -16,
                        child: Icon(
                          Icons.business_rounded,
                          color: Colors.white.withValues(alpha: 0.04),
                          size: 90,
                        ),
                      ),
                      // Centre icon
                      Center(
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: _kPrimary.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _kPrimary.withValues(alpha: 0.4),
                                  width: 1.5,
                                ),
                              ),
                              child: const Icon(
                                Icons.business_rounded,
                                color: _kPrimary,
                                size: 34,
                              ),
                            ),
                            // Verified badge
                            Positioned(
                              top: -6,
                              right: -10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: _kPrimary,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.verified_rounded,
                                      color: Colors.white,
                                      size: 10,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      'VERIFIED',
                                      style: GoogleFonts.googleSans(
                                        color: Colors.white,
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Info
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  child: Column(
                    children: [
                      Text(
                        campusName,
                        style: GoogleFonts.googleSans(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            color: Colors.white54,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            campusLocation,
                            style: GoogleFonts.googleSans(
                              color: Colors.white54,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Divider(color: Colors.white.withValues(alpha: 0.08)),
                      const SizedBox(height: 16),
                      Text(
                        'ASSOCIATED DOMAIN',
                        style: GoogleFonts.googleSans(
                          color: Colors.white38,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: _kPrimary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _kPrimary.withValues(alpha: 0.28),
                          ),
                        ),
                        child: Text(
                          campusDomain,
                          style: GoogleFonts.googleSans(
                            color: _kPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          TextButton(
            onPressed: onChangeCampus,
            child: Text(
              'Choose different campus',
              style: GoogleFonts.googleSans(
                color: Colors.white60,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

// ── Step 2: Academic Details ─────────────────────────────────────────────────

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MascotHeader(message: mascotMessage),
          const SizedBox(height: 28),
          Text(
            'Academic Details',
            style: GoogleFonts.googleSans(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          _OnboardingDropdown<String>(
            label: 'Branch / Programme',
            value: branch,
            items: _branches,
            onChanged: onBranchChanged,
          ),
          const SizedBox(height: 16),

          // Dual-degree toggle
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _kSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDualDegree
                    ? _kPrimary.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              children: [
                Transform.scale(
                  scale: 0.88,
                  child: Switch(
                    value: isDualDegree,
                    activeThumbColor: _kPrimary,
                    onChanged: onDualToggle,
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dual Degree',
                      style: GoogleFonts.googleSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      'I have an MSc programme',
                      style: GoogleFonts.googleSans(
                        color: Colors.white54,
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

// ── Step 3: Study Capacity ────────────────────────────────────────────────────

class _CapacityStep extends StatelessWidget {
  final String? selected;
  final String mascotMessage;
  final ValueChanged<String> onSelect;

  const _CapacityStep({
    required this.selected,
    required this.mascotMessage,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MascotHeader(message: mascotMessage),
          const SizedBox(height: 28),
          Text(
            'How busy are you this semester?',
            style: GoogleFonts.googleSans(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 24),

          ..._kCapacityOptions.asMap().entries.map((e) {
            final i = e.key;
            final opt = e.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _CapacityCard(
                option: opt,
                isSelected: selected == opt.value,
                animDelay: Duration(milliseconds: i * 70),
                onTap: () => onSelect(opt.value),
              ),
            );
          }),

          // Tip note
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: Colors.white38,
                  size: 14,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Most CS and Phoenix students choose 'Normal' to balance lab work and exam prep.",
                    style: GoogleFonts.googleSans(
                      color: Colors.white38,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

class _CapacityCard extends StatelessWidget {
  final _CapacityOption option;
  final bool isSelected;
  final Duration animDelay;
  final VoidCallback onTap;

  const _CapacityCard({
    required this.option,
    required this.isSelected,
    required this.animDelay,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 380) + animDelay,
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, 20 * (1 - v)),
          child: child,
        ),
      ),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isSelected ? _kPrimary.withValues(alpha: 0.18) : _kSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? _kPrimary
                  : Colors.white.withValues(alpha: 0.08),
              width: isSelected ? 1.5 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: _kPrimary.withValues(alpha: 0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _kPrimary.withValues(alpha: 0.28)
                          : Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      option.icon,
                      color: isSelected ? _kPrimary : Colors.white54,
                      size: 22,
                    ),
                  ),
                  const Spacer(),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (child, anim) => ScaleTransition(
                      scale: anim,
                      child: FadeTransition(opacity: anim, child: child),
                    ),
                    child: isSelected
                        ? Container(
                            key: const ValueKey('badge'),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _kPrimary,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.check_circle_outline_rounded,
                                  color: Colors.white,
                                  size: 11,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Selected',
                                  style: GoogleFonts.googleSans(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(key: ValueKey('empty')),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                option.title,
                style: GoogleFonts.googleSans(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                option.description,
                style: GoogleFonts.googleSans(
                  color: Colors.white60,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    color: Colors.white38,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    option.hours,
                    style: GoogleFonts.googleSans(
                      color: Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Steps 4–6: Questionnaire (card-list style preserved) ─────────────────────

class _QuestionStep extends StatelessWidget {
  final String mascotMessage;
  final List<String> options;
  final bool isMultiSelect;
  final String? selectedValue;
  final List<String>? selectedValues;
  final ValueChanged<String> onSelect;

  const _QuestionStep({
    required this.mascotMessage,
    required this.options,
    required this.isMultiSelect,
    this.selectedValue,
    this.selectedValues,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MascotHeader(message: mascotMessage),
          const SizedBox(height: 28),
          ...options.asMap().entries.map((e) {
            final i = e.key;
            final option = e.value;
            final isSelected = isMultiSelect
                ? (selectedValues?.contains(option) ?? false)
                : (selectedValue == option);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: _QuestionCard(
                label: option,
                isSelected: isSelected,
                isMultiSelect: isMultiSelect,
                animDelay: Duration(milliseconds: i * 55),
                onTap: () => onSelect(option),
              ),
            );
          }),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isMultiSelect;
  final Duration animDelay;
  final VoidCallback onTap;

  const _QuestionCard({
    required this.label,
    required this.isSelected,
    required this.isMultiSelect,
    required this.animDelay,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 320) + animDelay,
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - v)),
          child: child,
        ),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          decoration: BoxDecoration(
            color: isSelected ? _kPrimary.withValues(alpha: 0.22) : _kSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? _kPrimary
                  : Colors.white.withValues(alpha: 0.09),
              width: isSelected ? 1.5 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: _kPrimary.withValues(alpha: 0.14),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.googleSans(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Indicator (circle for single, rounded-rect for multi)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: isMultiSelect ? BoxShape.rectangle : BoxShape.circle,
                  color: isSelected ? _kPrimary : Colors.transparent,
                  borderRadius: isMultiSelect ? BorderRadius.circular(6) : null,
                  border: isSelected
                      ? null
                      : Border.all(color: Colors.white38, width: 1.5),
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 14,
                      )
                    : null,
              ),
            ],
          ),
        ),
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

  const _OnboardingTextField({
    required this.controller,
    required this.label,
    required this.hint,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.googleSans(color: Colors.white60, fontSize: 13),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          onChanged: onChanged,
          style: GoogleFonts.googleSans(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.googleSans(color: Colors.white24),
            filled: true,
            fillColor: _kSurface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kPrimary, width: 1.5),
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
          style: GoogleFonts.googleSans(color: Colors.white60, fontSize: 13),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: _kSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: value != null
                  ? _kPrimary.withValues(alpha: 0.4)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              dropdownColor: const Color(0xFF1E1E22),
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.white54,
              ),
              style: GoogleFonts.googleSans(color: Colors.white, fontSize: 15),
              hint: Text(
                'Select',
                style: GoogleFonts.googleSans(color: Colors.white38),
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
