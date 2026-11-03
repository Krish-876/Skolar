import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:Skolar/core/theme/app_theme.dart';

/// Global provider to control whether the navigation bar is visible.
/// Can be toggled to false during active immersive sessions (e.g. running focus timer).
final dockVisibilityProvider = StateProvider<bool>((ref) => true);

class AppShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _isNavBarVisible = true;

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navigationShell.currentIndex !=
        widget.navigationShell.currentIndex) {
      // Always show bottom nav when switching tabs
      _isNavBarVisible = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final showDock = ref.watch(dockVisibilityProvider);
    final isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final showBar = _isNavBarVisible && showDock && !isKeyboardOpen;
    final currentIndex = widget.navigationShell.currentIndex;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              // Do not scroll-hide in chat tab where input dock is docked
              if (widget.navigationShell.currentIndex == 2) {
                return false;
              }
              if (notification is ScrollUpdateNotification) {
                final delta = notification.scrollDelta ?? 0;
                // Instantly hide on scrolling down (delta > 2px)
                if (delta > 2.0) {
                  if (_isNavBarVisible) {
                    setState(() => _isNavBarVisible = false);
                  }
                } else if (delta < -2.0) {
                  // Instantly show on scrolling up (delta < -2px)
                  if (!_isNavBarVisible) {
                    setState(() => _isNavBarVisible = true);
                  }
                }
                // Always show when near the top of the scrollable
                if (notification.metrics.pixels <= 16 && !_isNavBarVisible) {
                  setState(() => _isNavBarVisible = true);
                }
              } else if (notification is UserScrollNotification) {
                if (notification.direction == ScrollDirection.reverse) {
                  if (_isNavBarVisible) {
                    setState(() => _isNavBarVisible = false);
                  }
                } else if (notification.direction == ScrollDirection.forward) {
                  if (!_isNavBarVisible) {
                    setState(() => _isNavBarVisible = true);
                  }
                }
              }
              return false;
            },
            child: widget.navigationShell,
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              ignoring: !showBar,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeInOut,
                offset: showBar ? Offset.zero : const Offset(0, 1.4),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  opacity: showBar ? 1.0 : 0.0,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        height: 64,
                        margin: const EdgeInsets.symmetric(horizontal: 18),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16151D),
                          borderRadius: BorderRadius.circular(36),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 4),
                            _PillNavItem(
                              icon: Icons.space_dashboard_rounded,
                              isSelected: currentIndex == 0,
                              onTap: () => _selectTab(0),
                            ),
                            const SizedBox(width: 28),
                            _PillNavItem(
                              icon: Icons.assignment_rounded,
                              isSelected: currentIndex == 1,
                              onTap: () => _selectTab(1),
                            ),
                            const Spacer(),
                            _CenterNovaButton(
                              isSelected: currentIndex == 2,
                              onTap: () => _selectTab(2),
                            ),
                            const Spacer(),
                            _PillNavItem(
                              icon: Icons.notes_rounded,
                              isSelected: currentIndex == 3,
                              onTap: () => _selectTab(3),
                            ),
                            const SizedBox(width: 28),
                            _PillNavItem(
                              icon: Icons.person_rounded,
                              isSelected: currentIndex == 4,
                              onTap: () => _selectTab(4),
                            ),
                            const SizedBox(width: 4),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _selectTab(int index) {
    if (!_isNavBarVisible) {
      setState(() => _isNavBarVisible = true);
    }
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }
}

class _PillNavItem extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _PillNavItem({
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: SizedBox(
        width: 44,
        height: 48,
        child: Center(
          child: AnimatedScale(
            scale: isSelected ? 1.10 : 1.0,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            child: Icon(
              icon,
              size: 24,
              color: isSelected
                  ? AppTheme.accentPurple
                  : Colors.white.withValues(alpha: 0.55),
            ),
          ),
        ),
      ),
    );
  }
}

class _CenterNovaButton extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;

  const _CenterNovaButton({required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(
            color: isSelected
                ? AppTheme.accentPurple
                : Colors.white.withValues(alpha: 0.9),
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.45),
                blurRadius: 12,
                spreadRadius: 1,
              )
            else
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
          ],
        ),
        child: const Center(
          child: Icon(
            Icons.auto_awesome_rounded,
            size: 23,
            color: AppTheme.primary,
          ),
        ),
      ),
    );
  }
}
