import 'package:Skolar/features/nova_chat/domain/entities/chat_message_entity.dart';
import 'package:Skolar/features/nova_chat/domain/entities/proposal_entity.dart';
import 'package:Skolar/features/nova_chat/domain/entities/study_plan_entity.dart';

abstract class INovaChatRepository {
  Future<ChatMessageEntity> sendMessage({
    required String userId,
    required String question,
  });

  Future<StudyPlanEntity> generateStudyPlan({
    required String userId,
    String triggerType = 'full_pass',
  });

  Future<Map<String, dynamic>> getStudentFacts({required String userId});

  Future<List<String>> getInitialSuggestions({required String userId});

  Future<bool> checkBackendHealth();

  Future<List<PendingProposalEntity>> getPendingProposals({
    required String userId,
  });

  Future<ProposalResolutionEntity> confirmProposal({
    required String userId,
    required String proposalId,
  });

  Future<ProposalResolutionEntity> rejectProposal({
    required String userId,
    required String proposalId,
  });

  Future<List<ProposalResolutionEntity>> confirmProposalTurn({
    required String userId,
    required String turnId,
  });

  Future<List<ProposalResolutionEntity>> rejectProposalTurn({
    required String userId,
    required String turnId,
  });
}
