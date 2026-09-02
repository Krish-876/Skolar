import 'package:Skolar/features/nova_chat/domain/entities/chat_message_entity.dart';
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
}
