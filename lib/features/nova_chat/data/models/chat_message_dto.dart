import 'package:Skolar/features/nova_chat/data/models/study_plan_dto.dart';
import 'package:Skolar/features/nova_chat/domain/entities/chat_message_entity.dart';

class NovaChatResponseDto {
  final String type;
  final String message;
  final Map<String, dynamic>? data;
  final List<String> suggestions;

  const NovaChatResponseDto({
    required this.type,
    required this.message,
    this.data,
    this.suggestions = const [],
  });

  factory NovaChatResponseDto.fromJson(Map<String, dynamic> json) {
    // Handle both old schema { "answer": "..." } and new polymorphic schema
    final type = json['type'] as String? ?? 'chat';
    final message =
        json['message'] as String? ?? json['answer'] as String? ?? '';
    final data = json['data'] as Map<String, dynamic>?;
    final rawSuggestions = json['suggestions'] as List<dynamic>? ?? [];
    final suggestions = rawSuggestions.map((s) => s.toString()).toList();

    return NovaChatResponseDto(
      type: type,
      message: message,
      data: data,
      suggestions: suggestions,
    );
  }

  ChatMessageEntity toEntity({required String id}) {
    NovaResponseType responseType;
    dynamic structuredData;

    switch (type) {
      case 'quiz':
        responseType = NovaResponseType.quiz;
        if (data != null) {
          final title = data!['title'] as String? ?? 'Quick Quiz';
          final questionsRaw = data!['questions'] as List<dynamic>? ?? [];
          final questions = questionsRaw.map((q) {
            final qMap = q as Map<String, dynamic>;
            final optionsRaw = qMap['options'] as List<dynamic>? ?? [];
            return QuizQuestionEntity(
              question: qMap['question'] as String? ?? '',
              options: optionsRaw.map((o) => o.toString()).toList(),
              correctIndex: qMap['correct_index'] as int? ?? 0,
              explanation: qMap['explanation'] as String? ?? '',
            );
          }).toList();
          structuredData = QuizEntity(title: title, questions: questions);
        }
        break;

      case 'plan':
        responseType = NovaResponseType.plan;
        if (data != null) {
          structuredData = StudyPlanDto.fromJson(data!).toEntity();
        }
        break;

      case 'flashcard':
        responseType = NovaResponseType.flashcard;
        if (data != null) {
          final title = data!['title'] as String? ?? 'Key Concepts';
          final cardsRaw = data!['cards'] as List<dynamic>? ?? [];
          final cards = cardsRaw.map((c) {
            final cMap = c as Map<String, dynamic>;
            return FlashcardItemEntity(
              front: cMap['front'] as String? ?? '',
              back: cMap['back'] as String? ?? '',
              keyTakeaway: cMap['key_takeaway'] as String?,
            );
          }).toList();
          structuredData = FlashcardEntity(title: title, cards: cards);
        }
        break;

      case 'practice_problem':
        responseType = NovaResponseType.practiceProblem;
        if (data != null) {
          final hintsRaw = data!['hints'] as List<dynamic>? ?? [];
          structuredData = PracticeProblemEntity(
            title: data!['title'] as String? ?? 'Practice Problem',
            topic: data!['topic'] as String? ?? 'General',
            difficulty: data!['difficulty'] as String? ?? 'Medium',
            problemStatement: data!['problem_statement'] as String? ?? '',
            hints: hintsRaw.map((h) => h.toString()).toList(),
            solution: data!['solution'] as String? ?? '',
          );
        }
        break;

      default:
        responseType = NovaResponseType.chat;
        structuredData = null;
    }

    return ChatMessageEntity(
      id: id,
      role: MessageRole.assistant,
      content: message,
      timestamp: DateTime.now(),
      status: MessageStatus.sent,
      responseType: responseType,
      structuredData: structuredData,
      suggestions: suggestions,
    );
  }
}
