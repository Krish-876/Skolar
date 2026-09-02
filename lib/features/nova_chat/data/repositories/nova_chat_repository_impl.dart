import 'package:uuid/uuid.dart';
import 'package:Skolar/features/nova_chat/data/datasources/nova_chat_remote_datasource.dart';
import 'package:Skolar/features/nova_chat/domain/entities/chat_message_entity.dart';
import 'package:Skolar/features/nova_chat/domain/entities/study_plan_entity.dart';
import 'package:Skolar/features/nova_chat/domain/repositories/i_nova_chat_repository.dart';

class NovaChatRepositoryImpl implements INovaChatRepository {
  final INovaChatRemoteDatasource _remoteDatasource;
  final Uuid _uuid;

  NovaChatRepositoryImpl({
    INovaChatRemoteDatasource? remoteDatasource,
    Uuid? uuid,
  })  : _remoteDatasource = remoteDatasource ?? NovaChatRemoteDatasource(),
        _uuid = uuid ?? const Uuid();

  @override
  Future<ChatMessageEntity> sendMessage({
    required String userId,
    required String question,
  }) async {
    final answer = await _remoteDatasource.sendMessage(
      userId: userId,
      question: question,
    );

    return ChatMessageEntity(
      id: _uuid.v4(),
      role: MessageRole.assistant,
      content: answer,
      timestamp: DateTime.now(),
      status: MessageStatus.sent,
    );
  }

  @override
  Future<StudyPlanEntity> generateStudyPlan({
    required String userId,
    String triggerType = 'full_pass',
  }) async {
    final planDto = await _remoteDatasource.runReasoning(
      userId: userId,
      triggerType: triggerType,
    );
    return planDto.toEntity();
  }

  @override
  Future<Map<String, dynamic>> getStudentFacts({
    required String userId,
  }) async {
    return _remoteDatasource.getFacts(userId: userId);
  }

  @override
  Future<bool> checkBackendHealth() async {
    return _remoteDatasource.checkHealth();
  }
}
