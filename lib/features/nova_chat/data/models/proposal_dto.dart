import 'package:Skolar/features/nova_chat/domain/entities/proposal_entity.dart';

/// backend/nova/schemas/proposals.py's ProposalKind is a plain string enum
/// on the wire ("standing_flag" | "situation_flag" | "nova_history" | "career_unit").
ProposalKind proposalKindFromWire(String? raw) {
  switch (raw) {
    case 'situation_flag':
      return ProposalKind.situationFlag;
    case 'nova_history':
      return ProposalKind.history;
    case 'career_unit':
      return ProposalKind.careerUnit;
    case 'standing_flag':
    default:
      return ProposalKind.standingFlag;
  }
}

class ProposalSummaryDto {
  final String id;
  final String turnId;
  final ProposalKind kind;
  final String summary;

  const ProposalSummaryDto({
    required this.id,
    required this.turnId,
    required this.kind,
    required this.summary,
  });

  factory ProposalSummaryDto.fromJson(Map<String, dynamic> json) {
    return ProposalSummaryDto(
      id: json['id'] as String? ?? '',
      turnId: json['turn_id'] as String? ?? '',
      kind: proposalKindFromWire(json['kind'] as String?),
      summary: json['summary'] as String? ?? '',
    );
  }

  ProposalSummaryEntity toEntity() => ProposalSummaryEntity(
    id: id,
    turnId: turnId,
    kind: kind,
    summary: summary,
  );
}

class PendingProposalDto extends ProposalSummaryDto {
  final DateTime createdAt;

  const PendingProposalDto({
    required super.id,
    required super.turnId,
    required super.kind,
    required super.summary,
    required this.createdAt,
  });

  factory PendingProposalDto.fromJson(Map<String, dynamic> json) {
    return PendingProposalDto(
      id: json['id'] as String? ?? '',
      turnId: json['turn_id'] as String? ?? '',
      kind: proposalKindFromWire(json['kind'] as String?),
      summary: json['summary'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  PendingProposalEntity toPendingEntity() => PendingProposalEntity(
    id: id,
    turnId: turnId,
    kind: kind,
    summary: summary,
    createdAt: createdAt,
  );
}

class ProposalResolutionDto {
  final String id;
  final ProposalKind kind;
  final String status; // "confirmed" | "rejected"
  final String? resultingRowId;

  const ProposalResolutionDto({
    required this.id,
    required this.kind,
    required this.status,
    this.resultingRowId,
  });

  factory ProposalResolutionDto.fromJson(Map<String, dynamic> json) {
    return ProposalResolutionDto(
      id: json['id'] as String? ?? '',
      kind: proposalKindFromWire(json['kind'] as String?),
      status: json['status'] as String? ?? 'rejected',
      resultingRowId: json['resulting_row_id'] as String?,
    );
  }

  ProposalResolutionEntity toEntity() => ProposalResolutionEntity(
    id: id,
    kind: kind,
    confirmed: status == 'confirmed',
    resultingRowId: resultingRowId,
  );
}
