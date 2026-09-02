import 'package:Skolar/features/nova_chat/domain/entities/chat_message_entity.dart';

class ChatMessageDto {
  final String id;
  final String role;
  final String content;
  final String timestamp;
  final String status;

  const ChatMessageDto({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    required this.status,
  });

  factory ChatMessageDto.fromJson(Map<String, dynamic> json) {
    return ChatMessageDto(
      id: json['id'] as String? ?? '',
      role: json['role'] as String? ?? 'user',
      content: json['content'] as String? ?? '',
      timestamp: json['timestamp'] as String? ?? DateTime.now().toIso8601String(),
      status: json['status'] as String? ?? 'sent',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role,
      'content': content,
      'timestamp': timestamp,
      'status': status,
    };
  }

  ChatMessageEntity toEntity() {
    MessageRole mappedRole;
    switch (role) {
      case 'assistant':
        mappedRole = MessageRole.assistant;
        break;
      case 'system':
        mappedRole = MessageRole.system;
        break;
      default:
        mappedRole = MessageRole.user;
    }

    MessageStatus mappedStatus;
    switch (status) {
      case 'sending':
        mappedStatus = MessageStatus.sending;
        break;
      case 'error':
        mappedStatus = MessageStatus.error;
        break;
      default:
        mappedStatus = MessageStatus.sent;
    }

    return ChatMessageEntity(
      id: id,
      role: mappedRole,
      content: content,
      timestamp: DateTime.tryParse(timestamp) ?? DateTime.now(),
      status: mappedStatus,
    );
  }

  factory ChatMessageDto.fromEntity(ChatMessageEntity entity) {
    return ChatMessageDto(
      id: entity.id,
      role: entity.role.name,
      content: entity.content,
      timestamp: entity.timestamp.toIso8601String(),
      status: entity.status.name,
    );
  }
}
