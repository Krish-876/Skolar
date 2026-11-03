import 'package:Skolar/features/auth/presentation/widgets/mascot_state.dart';
import 'package:Skolar/features/nova_chat/domain/entities/chat_message_entity.dart';
import 'package:Skolar/features/nova_chat/domain/entities/proposal_entity.dart';
import 'package:Skolar/features/nova_chat/domain/entities/study_plan_entity.dart';

class NovaChatState {
  final List<ChatMessageEntity> messages;
  final bool isThinking;
  final bool isBackendOnline;
  final MascotState mascotState;
  final String? errorMessage;
  final List<String> suggestions;
  final StudyPlanEntity? latestStudyPlan;
  // Keyed by ChatMessageEntity.proposalTurnId - tracks each proposed turn's
  // confirm/reject lifecycle independently of the (immutable) message list.
  final Map<String, ProposalTurnStatus> proposalTurnStatus;

  const NovaChatState({
    this.messages = const [],
    this.isThinking = false,
    this.isBackendOnline = true,
    this.mascotState = MascotState.idle,
    this.errorMessage,
    this.suggestions = const [],
    this.latestStudyPlan,
    this.proposalTurnStatus = const {},
  });

  ProposalTurnStatus statusForTurn(String turnId) =>
      proposalTurnStatus[turnId] ?? ProposalTurnStatus.pending;

  NovaChatState copyWith({
    List<ChatMessageEntity>? messages,
    bool? isThinking,
    bool? isBackendOnline,
    MascotState? mascotState,
    String? errorMessage,
    List<String>? suggestions,
    StudyPlanEntity? latestStudyPlan,
    Map<String, ProposalTurnStatus>? proposalTurnStatus,
  }) {
    return NovaChatState(
      messages: messages ?? this.messages,
      isThinking: isThinking ?? this.isThinking,
      isBackendOnline: isBackendOnline ?? this.isBackendOnline,
      mascotState: mascotState ?? this.mascotState,
      errorMessage: errorMessage,
      suggestions: suggestions ?? this.suggestions,
      latestStudyPlan: latestStudyPlan ?? this.latestStudyPlan,
      proposalTurnStatus: proposalTurnStatus ?? this.proposalTurnStatus,
    );
  }
}
