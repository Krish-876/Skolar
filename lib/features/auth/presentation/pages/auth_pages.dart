import 'package:flutter/material.dart';
import 'package:nova/core/theme/app_theme.dart';
import 'package:nova/features/auth/presentation/widgets/mascot_state.dart';
import 'package:nova/features/auth/presentation/widgets/nova_mascot.dart';
import 'package:nova/features/auth/presentation/widgets/reg_widget.dart';
import 'package:nova/features/auth/presentation/widgets/signin_widget.dart';
import 'package:nova/features/auth/presentation/widgets/space_background.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  bool _showSignIn = true;
  MascotState _mascotState = MascotState.idle;

  late final AnimationController _formSwitchCtrl;
  late final Animation<double> _formFadeAnim;
  late final Animation<Offset> _formSlideAnim;

  static const double _mascotSize = 150.0;
  // How much of the mascot overlaps into the card from the top
  static const double _mascotOverlap = 24.0;
  // How much of the mascot peeks above the card (rest of mascot height)
  static const double _mascotAboveCard = _mascotSize - _mascotOverlap;

  @override
  void initState() {
    super.initState();
    _formSwitchCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();

    _formFadeAnim = CurvedAnimation(
      parent: _formSwitchCtrl,
      curve: Curves.easeOut,
    );

    _formSlideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _formSwitchCtrl,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _formSwitchCtrl.dispose();
    super.dispose();
  }

  void _toggleForm() {
    _formSwitchCtrl.reset();
    setState(() {
      _showSignIn = !_showSignIn;
      _mascotState = MascotState.idle;
    });
    _formSwitchCtrl.forward();
  }

  void _onMascotStateChanged(MascotState state) {
    if (_mascotState != state) {
      setState(() => _mascotState = state);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ── KEY FIX: Render SpaceBackground outside the Scaffold entirely,
    // using a top-level Stack anchored to the full screen via MediaQuery size.
    // This way the Scaffold (and keyboard inset resizing) never affects it.
    final screenSize = MediaQuery.of(context).size;

    return Stack(
      children: [
        // ── Layer 0: Space background — truly full-screen, never moves ──
        SizedBox(
          width: screenSize.width,
          height: screenSize.height,
          child: const SpaceBackground(child: SizedBox.expand()),
        ),
  
        // ── Layer 1: The actual Scaffold (transparent) ──
        Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.transparent,
      body: SafeArea(
          // Don't let SafeArea eat the bottom — we handle it in the scroll padding
          bottom: false,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            // ── KEY FIX 2: Dynamically pad the bottom so content scrolls above
            // the keyboard. MediaQuery.viewInsets.bottom is 0 when keyboard is
            // hidden and equals keyboard height when visible.
            padding: EdgeInsets.fromLTRB(
              24,
              16,
              24,
              // viewInsets is still valid here — it comes from the inner
              // MediaQuery which the Scaffold provides, but since
              // resizeToAvoidBottomInset: false the Scaffold itself won't
              // shrink — only this padding value changes.
              MediaQuery.of(context).viewInsets.bottom + 32,
            ),
            child: Column(
              children: [
                // ── KEY FIX 3: Mascot lives INSIDE the scroll view, directly
                // above the card. They scroll together as one unit, so they
                // never separate. The mascot overlaps the card via a Stack.
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topCenter,
                  children: [
                    // ── Auth Card ──────────────────────────────────────────
                    // Top padding creates the "hole" for the mascot to sit in
                    Padding(
                      padding: const EdgeInsets.only(top: _mascotAboveCard),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: AppTheme.surfaceGradient,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusXl),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF7B2FFF)
                                  .withValues(alpha: 0.12),
                              blurRadius: 40,
                              spreadRadius: 2,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.fromLTRB(
                            24, _mascotOverlap + 12, 24, 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Title
                            SizedBox(height: 20),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: Text(
                                _showSignIn
                                    ? 'Welcome back'
                                    : 'Create account',
                                key: ValueKey(_showSignIn),
                                style: TextStyle(
                                  color: AppTheme.onSurface,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Subtitle
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: Text(
                                _showSignIn
                                    ? 'Sign in to your account'
                                    : 'Join Nova today',
                                key: ValueKey('sub_$_showSignIn'),
                                style: TextStyle(
                                  color: AppTheme.onBackground2,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),
                            // Form
                            FadeTransition(
                              opacity: _formFadeAnim,
                              child: SlideTransition(
                                position: _formSlideAnim,
                                child: _showSignIn
                                    ? SignInForm(
                                        toggleForm: _toggleForm,
                                        onMascotStateChanged:
                                            _onMascotStateChanged,
                                      )
                                    : RegistrationForm(
                                        toggleForm: _toggleForm,
                                        onMascotStateChanged:
                                            _onMascotStateChanged,
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── Mascot — sits on top of the card, centred ──────────
                    // Positioned at the very top of the Stack, which aligns it
                    // to straddle the card's top edge via the Padding above.
                    // It scrolls WITH the card, so they never separate.
                    SizedBox(
                      height: _mascotSize,
                      width: _mascotSize,
                      child: NovaMascot(state: _mascotState),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      ],
    );
  }
}