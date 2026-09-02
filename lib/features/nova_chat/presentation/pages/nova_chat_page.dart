import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Skolar/features/auth/presentation/widgets/mascot_state.dart';
import 'package:Skolar/features/nova_chat/presentation/providers/nova_chat_provider.dart';
import 'package:Skolar/features/nova_chat/presentation/widgets/nova_chat_app_bar.dart';
import 'package:Skolar/features/nova_chat/presentation/widgets/nova_chat_bubble.dart';
import 'package:Skolar/features/nova_chat/presentation/widgets/nova_chat_input_dock.dart';
import 'package:Skolar/features/nova_chat/presentation/widgets/nova_quick_suggestions.dart';
import 'package:Skolar/features/nova_chat/presentation/widgets/nova_thinking_indicator.dart';
import 'package:Skolar/shared/providers/global_providers.dart';

class NovaChatPage extends ConsumerStatefulWidget {
  const NovaChatPage({super.key});

  @override
  ConsumerState<NovaChatPage> createState() => _NovaChatPageState();
}

class _NovaChatPageState extends ConsumerState<NovaChatPage> {
  late final ScrollController _scrollCtrl;
  final GlobalKey _inputDockKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _scrollCtrl = ScrollController();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(novaChatProvider);
    final chatNotifier = ref.read(novaChatProvider.notifier);
    final user = ref.watch(userProvider);
    final topPadding = MediaQuery.of(context).padding.top + 64;
    final bottomPadding = (chatState.suggestions.isNotEmpty ? 190.0 : 120.0) +
        MediaQuery.of(context).padding.bottom;

    // Scroll to bottom whenever messages list grows or thinking state updates
    ref.listen(novaChatProvider, (previous, next) {
      if (previous?.messages.length != next.messages.length ||
          previous?.isThinking != next.isThinking) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Ambient Glassmorphic Background Glow Layer
          Positioned(
            top: 60,
            right: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF9153DE).withValues(alpha: 0.22),
                    const Color(0xFF9153DE).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 140,
            left: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF7A3EC8).withValues(alpha: 0.18),
                    const Color(0xFF7A3EC8).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          // 2. Full-bleed Scrollable Chat Stream (leaks under top and bottom frosted bars)
          ListView.builder(
            controller: _scrollCtrl,
            padding: EdgeInsets.only(
              top: topPadding + 10,
              bottom: bottomPadding,
            ),
            physics: const BouncingScrollPhysics(),
            itemCount: chatState.messages.length +
                (chatState.isThinking ? 1 : 0),
            itemBuilder: (context, index) {
              if (index < chatState.messages.length) {
                final msg = chatState.messages[index];
                return NovaChatBubble(
                  key: ValueKey(msg.id),
                  message: msg,
                  userAvatarSvg: user.avatarData,
                );
              }
              return const NovaThinkingIndicator();
            },
          ),

          // 3. Frosted Top App Bar (Chat content leaks through with BackdropFilter blur)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: NovaChatAppBar(
              isBackendOnline: chatState.isBackendOnline,
              isThinking: chatState.isThinking,
              mascotState: chatState.mascotState,
              onClearChat: () => chatNotifier.clearChat(),
            ),
          ),

          // 4. Frosted Bottom Dock & Suggestions (Chat content leaks through)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Suggestions Pills (Loads question into input dock on click)
                if (chatState.suggestions.isNotEmpty)
                  NovaQuickSuggestions(
                    suggestions: chatState.suggestions,
                    onSelectSuggestion: (suggestion) {
                      final state = _inputDockKey.currentState;
                      if (state != null) {
                        (state as dynamic).setInputText(suggestion);
                      } else {
                        chatNotifier.sendMessage(suggestion);
                      }
                    },
                  ),

                // Frosted Input Dock
                NovaChatInputDock(
                  key: _inputDockKey,
                  isThinking: chatState.isThinking,
                  onSendMessage: (text) => chatNotifier.sendMessage(text),
                  onFocusChanged: (hasFocus) {
                    chatNotifier.setMascotState(
                      hasFocus ? MascotState.watchingEmail : MascotState.idle,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
