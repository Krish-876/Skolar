enum MessageRole { user, assistant, system }

enum MessageStatus { sending, sent, error }

class ChatMessageEntity {
  final String id;
  final MessageRole role;
  final String content;
  final DateTime timestamp;
  final MessageStatus status;
  final String? errorMessage;
  final dynamic structuredData; // Optional e.g. StudyPlanEntity

  const ChatMessageEntity({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.status = MessageStatus.sent,
    this.errorMessage,
    this.structuredData,
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
    dynamic structuredData,
  }) {
    return ChatMessageEntity(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      structuredData: structuredData ?? this.structuredData,
    );
  }
}
