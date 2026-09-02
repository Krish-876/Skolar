enum MessageRole { user, assistant, system }

enum MessageStatus { sending, sent, error }

enum NovaResponseType { chat, quiz, plan, flashcard, practiceProblem }

// ── Quiz Entities ─────────────────────────────────────────────────────────────
class QuizQuestionEntity {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  const QuizQuestionEntity({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });
}

class QuizEntity {
  final String title;
  final List<QuizQuestionEntity> questions;

  const QuizEntity({required this.title, required this.questions});
}

// ── Flashcard Entities ────────────────────────────────────────────────────────
class FlashcardItemEntity {
  final String front;
  final String back;
  final String? keyTakeaway;

  const FlashcardItemEntity({
    required this.front,
    required this.back,
    this.keyTakeaway,
  });
}

class FlashcardEntity {
  final String title;
  final List<FlashcardItemEntity> cards;

  const FlashcardEntity({required this.title, required this.cards});
}

// ── Practice Problem Entities ────────────────────────────────────────────────
class PracticeProblemEntity {
  final String title;
  final String topic;
  final String difficulty;
  final String problemStatement;
  final List<String> hints;
  final String solution;

  const PracticeProblemEntity({
    required this.title,
    required this.topic,
    required this.difficulty,
    required this.problemStatement,
    required this.hints,
    required this.solution,
  });
}

// ── Unified Chat Message Entity ──────────────────────────────────────────────
class ChatMessageEntity {
  final String id;
  final MessageRole role;
  final String content;
  final DateTime timestamp;
  final MessageStatus status;
  final String? errorMessage;
  final NovaResponseType responseType;
  final dynamic
  structuredData; // QuizEntity | StudyPlanEntity | FlashcardEntity | PracticeProblemEntity
  final List<String> suggestions;

  const ChatMessageEntity({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.status = MessageStatus.sent,
    this.errorMessage,
    this.responseType = NovaResponseType.chat,
    this.structuredData,
    this.suggestions = const [],
  });

  bool get isUser => role == MessageRole.user;
  bool get isAssistant => role == MessageRole.assistant;

  ChatMessageEntity copyWith({
    String? id,
    MessageRole? role,
    String? content,
    DateTime? timestamp,
    MessageStatus? status,
    String? errorMessage,
    NovaResponseType? responseType,
    dynamic structuredData,
    List<String>? suggestions,
  }) {
    return ChatMessageEntity(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      responseType: responseType ?? this.responseType,
      structuredData: structuredData ?? this.structuredData,
      suggestions: suggestions ?? this.suggestions,
    );
  }
}
