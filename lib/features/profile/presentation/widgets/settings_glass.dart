import 'package:flutter/material.dart';
import 'package:Skolar/core/widgets/glass_background.dart';
import 'package:Skolar/features/profile/presentation/widgets/left_painter.dart';

class SettingsGlassMenu extends StatelessWidget {
  const SettingsGlassMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      'Edit profile',
      'Privacy and Security',
      'Language',
      'Support/Help',
      'About',
      'Upgrade to premium',
      'Logout',
    ];

    return Center(
      child: SizedBox(
        height: 350,
        width: 450,
        child: CustomPaint(
          foregroundPainter: LeftHighlightPainter(),
          child: Container(
            height: 350,
            width: 450,
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(40),
          
              // subtle outer glow
              
            ),
            child: Stack(
              children: [
                /// Main Glass Card
                GlassCard(
                  borderRadius: 40,
                  child: ShaderMask(
              shaderCallback: (Rect rect) {
          return const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              Colors.white,
              Colors.transparent,
            ],
            stops: [0.0, 0.85, 0.8],
          ).createShader(rect);
              },
              blendMode: BlendMode.dstIn,
              child: ShaderMask(
              shaderCallback: (Rect rect) {
          return const LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.white,
              Colors.white,
              Colors.transparent,
            ],
            stops: [0.0, 0.85, 0.6],
          ).createShader(rect);
              },
              blendMode: BlendMode.dstIn,
            
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: 40,
                        right: 40,
                        top: 30,
                        bottom: 40,
                      ),
                      
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(
                          items.length,
                          (index) => _SettingsTile(
                            title: items[index],
                            showDivider: index != items.length - 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                ),
                )
          
                
          
                /// Right edge highlight
                
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final String title;
  final bool showDivider;

  const _SettingsTile({
    required this.title,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),

                Icon(
                  Icons.chevron_right,
                  color: Colors.white.withOpacity(0.9),
                  size: 28,
                ),
              ],
            ),
          ),
        ),

        if (showDivider)
          Divider(
            color: Colors.white.withOpacity(0.08),
            thickness: 1,
            height: 0,
          ),
      ],
    );
  }
}