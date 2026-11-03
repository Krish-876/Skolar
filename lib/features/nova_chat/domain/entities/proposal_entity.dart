/// Mirrors backend/nova/schemas/proposals.py's ProposalKind literal.
enum ProposalKind { standingFlag, situationFlag, history, careerUnit }

/// Local-only UI state for a proposed turn's resolution - the backend has
/// no such concept, this just tracks what the confirm/reject buttons should
/// show while the request is in flight or has settled.
enum ProposalTurnStatus { pending, submitting, confirmed, rejected }

/// What the client actually renders as a confirm/reject chip - matches
/// ProposalSummary in backend/nova/schemas/proposals.py.
class ProposalSummaryEntity {
  final String id;
  final String turnId;
  final ProposalKind kind;
  final String summary;

  const ProposalSummaryEntity({
    required this.id,
    required this.turnId,
    required this.kind,
    required this.summary,
  });
}

/// Mirrors PendingProposal (ProposalSummary + createdAt) - used by the
/// GET /proposals/{user_id}/pending listing.
class PendingProposalEntity extends ProposalSummaryEntity {
  final DateTime createdAt;

  const PendingProposalEntity({
    required super.id,
    required super.turnId,
    required super.kind,
    required super.summary,
    required this.createdAt,
  });
}

/// Mirrors ProposalResolution - the result of a confirm/reject call.
class ProposalResolutionEntity {
  final String id;
  final ProposalKind kind;
  final bool confirmed;
  final String? resultingRowId;

  const ProposalResolutionEntity({
    required this.id,
    required this.kind,
    required this.confirmed,
    this.resultingRowId,
  });
}
