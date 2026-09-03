import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:Skolar/features/nova_chat/domain/entities/study_plan_entity.dart';

import 'package:Skolar/features/nova_chat/presentation/widgets/nova_fullscreen_modal.dart';

class NovaStudyPlanCard extends StatelessWidget {
  final StudyPlanEntity plan;
  final bool isFullScreen;

  const NovaStudyPlanCard({
    super.key,
    required this.plan,
    this.isFullScreen = false,
  });

  Color _getPriorityColor(int priority) {
    switch (priority) {
      case 1:
        return const Color(0xFFFF5353); // Crimson Red (High priority)
      case 2:
        return const Color(0xFFFFB038); // Amber (Medium)
      case 3:
        return const Color(0xFF8C5BE8); // Brand Purple (Standard)
      default:
        return const Color(0xFF63C8D4); // Cyan
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // Sleek blacker card matching obsidian theme
        color: const Color(0xFF16151D),
        borderRadius: isFullScreen
            ? BorderRadius.circular(20)
            : const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(20),
                bottomLeft: Radius.circular(6),
              ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF22202C),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: const Icon(
                  Icons.school_rounded,
                  color: Color(0xFF8C5BE8),
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Today's Study Plan",
                  style: GoogleFonts.googleSans(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (plan.stale) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    "Cached",
                    style: GoogleFonts.googleSans(
                      color: Colors.amber,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              if (!isFullScreen) ...[
                const SizedBox(width: 4),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  icon: const Icon(
                    Icons.fullscreen_rounded,
                    color: Colors.white70,
                    size: 20,
                  ),
                  tooltip: 'Full screen',
                  onPressed: () {
                    NovaFullScreenModal.show(
                      context,
                      title: "Today's Study Plan",
                      subtitle:
                          'AI Optimized Daily Roadmap (${plan.items.length} tasks)',
                      child: NovaStudyPlanCard(plan: plan, isFullScreen: true),
                    );
                  },
                ),
              ],
            ],
          ),

          if (plan.summary != null && plan.summary!.isNotEmpty) ...[
            const SizedBox(height: 12),
            SelectableText(
              plan.summary!,
              style: GoogleFonts.googleSans(
                color: const Color(0xFFA8A8B6),
                fontSize: 13.5,
                height: 1.35,
              ),
            ),
          ],

          const SizedBox(height: 14),
          Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
          const SizedBox(height: 14),

          // Actionable Items List
          ...plan.items.map((item) {
            final pColor = _getPriorityColor(item.priority);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0E16),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: pColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            'P${item.priority}',
                            style: GoogleFonts.googleSans(
                              color: pColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.subject,
                            style: GoogleFonts.googleSans(
                              color: const Color(0xFFD4CFE6),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      item.task,
                      style: GoogleFonts.googleSans(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      "Why: ${item.reason}",
                      style: GoogleFonts.googleSans(
                        color: const Color(0xFF7A788A),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
