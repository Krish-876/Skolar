import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:Skolar/features/nova_chat/domain/entities/proposal_entity.dart';

/// Attached below an assistant bubble whenever that turn proposed one or
/// more facts to remember (spec §5). Confirm/reject is batched per turn,
/// matching the backend's default: one action resolves everything this
/// turn proposed, not each fact separately.
class NovaProposalCard extends StatelessWidget {
  final String turnId;
  final List<ProposalSummaryEntity> proposals;
  final ProposalTurnStatus status;
  final VoidCallback onConfirm;
  final VoidCallback onReject;

  const NovaProposalCard({
    super.key,
    required this.turnId,
    required this.proposals,
    required this.status,
    required this.onConfirm,
    required this.onReject,
  });

  static IconData _iconForKind(ProposalKind kind) {
    switch (kind) {
      case ProposalKind.standingFlag:
        return Icons.push_pin_rounded;
      case ProposalKind.situationFlag:
        return Icons.event_note_rounded;
      case ProposalKind.history:
        return Icons.history_rounded;
      case ProposalKind.careerUnit:
        return Icons.trending_up_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (proposals.isEmpty) return const SizedBox.shrink();

    if (status == ProposalTurnStatus.confirmed) {
      return _buildResolvedPill(
        icon: Icons.check_circle_rounded,
        color: const Color(0xFF4CAF50),
        label: proposals.length > 1 ? "Remembered." : 'Remembered.',
      );
    }
    if (status == ProposalTurnStatus.rejected) {
      return _buildResolvedPill(
        icon: Icons.close_rounded,
        color: const Color(0xFF7A788A),
        label: 'Not saved.',
      );
    }

    final isSubmitting = status == ProposalTurnStatus.submitting;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF16151D),
          borderRadius: const BorderRadius.only(
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
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8C5BE8).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.bookmark_add_rounded,
                    color: Color(0xFF8C5BE8),
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Want me to remember this?',
                    style: GoogleFonts.googleSans(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...proposals.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F0E16),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _iconForKind(p.kind),
                        color: const Color(0xFFB388FF),
                        size: 15,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          p.summary,
                          style: GoogleFonts.googleSans(
                            color: const Color(0xFFD4CFE6),
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: _SecondaryButton(
                    label: 'Not now',
                    enabled: !isSubmitting,
                    onTap: onReject,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PrimaryButton(
                    label: 'Remember this',
                    isLoading: isSubmitting,
                    onTap: onConfirm,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResolvedPill({
    required IconData icon,
    required Color color,
    required String label,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF16151D),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.googleSans(
                color: const Color(0xFFA8A8B6),
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback onTap;

  const _PrimaryButton({
    required this.label,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF8C5BE8),
          borderRadius: BorderRadius.circular(16),
          boxShadow: isLoading
              ? []
              : const [
                  BoxShadow(
                    color: Color(0xFF5A2DA3),
                    offset: Offset(0, 3),
                    blurRadius: 0,
                  ),
                ],
        ),
        child: isLoading
            ? const SizedBox(
                height: 14,
                width: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: GoogleFonts.googleSans(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _SecondaryButton({
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF22202E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Text(
            label,
            style: GoogleFonts.googleSans(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
