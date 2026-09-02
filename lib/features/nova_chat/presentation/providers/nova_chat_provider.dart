import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:Skolar/features/auth/presentation/widgets/mascot_state.dart';
import 'package:Skolar/features/nova_chat/data/datasources/nova_chat_remote_datasource.dart';
import 'package:Skolar/features/nova_chat/data/repositories/nova_chat_repository_impl.dart';
import 'package:Skolar/features/nova_chat/domain/entities/chat_message_entity.dart';
import 'package:Skolar/features/nova_chat/domain/repositories/i_nova_chat_repository.dart';
import 'package:Skolar/features/nova_chat/presentation/providers/nova_chat_state.dart';

final novaChatRepositoryProvider = Provider<INovaChatRepository>((ref) {
  return NovaChatRepositoryImpl(
    remoteDatasource: NovaChatRemoteDatasource(),
  );
});

final novaChatProvider =
    StateNotifierProvider.autoDispose<NovaChatNotifier, NovaChatState>((ref) {
  final repo = ref.watch(novaChatRepositoryProvider);
  return NovaChatNotifier(repo);
});

class NovaChatNotifier extends StateNotifier<NovaChatState> {
  final INovaChatRepository _repository;
  final Uuid _uuid = const Uuid();

  NovaChatNotifier(this._repository) : super(const NovaChatState()) {
    _initWelcomeMessage();
    checkHealth();
  }

  void _initWelcomeMessage() {
    final welcomeMsg = ChatMessageEntity(
      id: _uuid.v4(),
      role: MessageRole.assistant,
      content:
          "Hey there! I'm **Nova**, your personal AI study co-pilot.\n\nI have real-time access to your preparation telemetry and syllabus. Ask me questions, test your understanding, or ask me to **generate today's study plan**.",
      timestamp: DateTime.now(),
      status: MessageStatus.sent,
    );
    state = state.copyWith(messages: [welcomeMsg]);
  }

  String _getUserId() {
    final user = Supabase.instance.client.auth.currentUser;
    final uid = user?.id ?? 'dev-student-01';
    debugPrint('🔵 [NovaChatNotifier] Using User ID: $uid');
    return uid;
  }

  void setMascotState(MascotState mascotState) {
    state = state.copyWith(mascotState: mascotState);
  }

  Future<void> checkHealth() async {
    debugPrint('🔵 [NovaChatNotifier] Checking Nova backend health...');
    final online = await _repository.checkBackendHealth();
    debugPrint('🟢 [NovaChatNotifier] Health check result: $online');
    state = state.copyWith(isBackendOnline: online);
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    debugPrint('🔵 [NovaChatNotifier] sendMessage called with: "$trimmed"');

    final userMsgId = _uuid.v4();
    final userMessage = ChatMessageEntity(
      id: userMsgId,
      role: MessageRole.user,
      content: trimmed,
      timestamp: DateTime.now(),
      status: MessageStatus.sent,
    );

    // Optimistically append user message, dismiss suggestions & set mascot thinking
    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isThinking: true,
      mascotState: MascotState.idle,
      errorMessage: null,
      suggestions: const [],
    );

    try {
      // Special trigger detection if user asks for study plan
      final lower = trimmed.toLowerCase();
      final isStudyPlanRequest = lower.contains('study plan') ||
          lower.contains('what should i study') ||
          lower.contains('what do i study') ||
          lower.contains('what to study') ||
          lower.contains('today plan') ||
          lower.contains("today's plan") ||
          lower.contains('todays plan') ||
          lower.contains('daily plan') ||
          lower.contains('study schedule') ||
          lower.contains('study roadmap');

      if (isStudyPlanRequest) {
        debugPrint('🔵 [NovaChatNotifier] Routing to reasoning engine for study plan...');
        await generateStudyPlan(directPrompt: trimmed);
        return;
      }

      debugPrint('🔵 [NovaChatNotifier] Calling repository.sendMessage...');
      final assistantMessage = await _repository.sendMessage(
        userId: _getUserId(),
        question: trimmed,
      );

      debugPrint('🟢 [NovaChatNotifier] Received assistant response: ${assistantMessage.content}');

      state = state.copyWith(
        messages: [...state.messages, assistantMessage],
        isThinking: false,
        mascotState: MascotState.idle,
      );
    } catch (e, st) {
      debugPrint('🔴 [NovaChatNotifier] sendMessage Error: $e\n$st');
      final errorAssistantMsg = ChatMessageEntity(
        id: _uuid.v4(),
        role: MessageRole.assistant,
        content:
            "**Could not complete request**\n\n${e.toString().replaceAll('Exception: ', '')}",
        timestamp: DateTime.now(),
        status: MessageStatus.error,
        errorMessage: e.toString(),
      );

      state = state.copyWith(
        messages: [...state.messages, errorAssistantMsg],
        isThinking: false,
        mascotState: MascotState.lookingAway,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> generateStudyPlan({String? directPrompt}) async {
    state = state.copyWith(isThinking: true, errorMessage: null);
    debugPrint('🔵 [NovaChatNotifier] generateStudyPlan started');

    try {
      final plan = await _repository.generateStudyPlan(
        userId: _getUserId(),
        triggerType: 'full_pass',
      );

      debugPrint('🟢 [NovaChatNotifier] Study plan received: ${plan.items.length} items');

      String content = "**Here is your customized study plan for today:**\n\n";
      if (plan.summary != null && plan.summary!.isNotEmpty) {
        content += "> *${plan.summary}*\n\n";
      }

      for (final item in plan.items) {
        content += "• **Priority ${item.priority} (${item.subject})**: ${item.task}\n  *Why: ${item.reason}*\n\n";
      }

      if (plan.stale && plan.note != null) {
        content += "\n*Note: ${plan.note}*";
      }

      final assistantMsg = ChatMessageEntity(
        id: _uuid.v4(),
        role: MessageRole.assistant,
        content: content.trim(),
        timestamp: DateTime.now(),
        status: MessageStatus.sent,
        structuredData: plan,
      );

      state = state.copyWith(
        messages: [...state.messages, assistantMsg],
        isThinking: false,
        latestStudyPlan: plan,
        mascotState: MascotState.idle,
      );
    } catch (e, st) {
      debugPrint('🔴 [NovaChatNotifier] generateStudyPlan Error: $e\n$st');
      final errorMsg = ChatMessageEntity(
        id: _uuid.v4(),
        role: MessageRole.assistant,
        content: "**Failed to generate study plan**\n\n$e",
        timestamp: DateTime.now(),
        status: MessageStatus.error,
      );

      state = state.copyWith(
        messages: [...state.messages, errorMsg],
        isThinking: false,
        mascotState: MascotState.lookingAway,
      );
    }
  }

  void clearChat() {
    debugPrint('🔵 [NovaChatNotifier] Clearing chat');
    state = state.copyWith(
      messages: [],
      suggestions: const [
        'What do I study today?',
        'Explain Quantum Tunneling in simple terms',
        'Review my weak areas in Thermodynamics',
        'Give me a 30-minute high-yield practice quiz',
      ],
    );
    _initWelcomeMessage();
  }
}
