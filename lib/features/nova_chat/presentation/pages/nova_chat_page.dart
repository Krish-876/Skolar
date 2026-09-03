import 'dart:math';

import 'package:dotlottie_loader/dotlottie_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart' as lottie;
import 'package:Skolar/core/theme/app_theme.dart';
import 'package:Skolar/features/auth/presentation/widgets/mascot_state.dart';
import 'package:Skolar/features/nova_chat/domain/entities/chat_message_entity.dart';
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
  bool _inputHasText = false;

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
    // "Empty" means the user hasn't sent anything yet — the auto-seeded
    // welcome message from the assistant doesn't count, so the greeting
    // stays up until the first real user message lands.
    final hasUserMessage = chatState.messages.any(
      (m) => m.role == MessageRole.user,
    );
    final topPadding = MediaQuery.of(context).padding.top + 64;
    final bottomPadding =
        (chatState.suggestions.isNotEmpty ? 120.0 : 72.0) +
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
          if (hasUserMessage)
            ListView.builder(
              controller: _scrollCtrl,
              padding: EdgeInsets.only(
                top: topPadding + 10,
                bottom: bottomPadding,
              ),
              physics: const BouncingScrollPhysics(),
              itemCount:
                  chatState.messages.length + (chatState.isThinking ? 1 : 0),
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
            )
          else
            Padding(
              padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
              child: _NovaChatGreeting(userName: user.name),
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
                // Hidden once a suggestion is picked (fills the textbox);
                // reappear only once the textbox is emptied again.
                if (chatState.suggestions.isNotEmpty && !_inputHasText)
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
                  onHasTextChanged: (hasText) {
                    setState(() => _inputHasText = hasText);
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

/// Empty-state greeting shown before the user sends their first message —
/// the Chat.lottie mascot plus a short, varying greeting line, matching the
/// feel of Claude.ai's new-chat greeting. Picked once per mount so it
/// doesn't shuffle on every rebuild while the empty state is showing.
class _NovaChatGreeting extends StatefulWidget {
  final String userName;
  const _NovaChatGreeting({required this.userName});

  @override
  State<_NovaChatGreeting> createState() => _NovaChatGreetingState();
}

class _NovaChatGreetingState extends State<_NovaChatGreeting> {
  late final String _greeting = _pickGreeting(widget.userName);

  static String _pickGreeting(String name) {
    final hasName = name.trim().isNotEmpty && name.trim() != 'Student';
    final hour = DateTime.now().hour;
    final timeOfDay = hour < 12
        ? 'morning'
        : (hour < 17 ? 'afternoon' : 'evening');

    final options = hasName
        ? ['Good $timeOfDay, $name', 'Hello, $name', 'Hi there, $name']
        : ['Good $timeOfDay', 'Hi there', 'Good to see you'];
    return options[Random().nextInt(options.length)];
  }

  @override
  Widget build(BuildContext context) {
    // The greeting sits in a Stack(fit: StackFit.expand), so it's forced
    // into whatever height remains once the keyboard opens (e.g. tapping
    // the input dock while the greeting is still showing, just before
    // send registers the first user message). LayoutBuilder + a scroll
    // view lets it shrink-scroll instead of overflowing when that height
    // drops below the animation + text's natural size.
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Align(
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 220,
                    width: 220,
                    child: DotLottieLoader.fromAsset(
                      'assets/animations/Chat.lottie',
                      frameBuilder: (context, dotlottie) {
                        if (dotlottie == null) {
                          return const SizedBox.shrink();
                        }
                        return lottie.Lottie.memory(
                          dotlottie.animations.values.single,
                          fit: BoxFit.contain,
                          // Chat.lottie ships its illustration pieces as
                          // external raster assets (u/p refs, not inline
                          // base64) rather than embedded images, so they
                          // need to be resolved by hand or the mascot
                          // renders with its artwork missing.
                          imageProviderFactory: (asset) {
                            final bytes = dotlottie.images[asset.fileName];
                            return bytes != null ? MemoryImage(bytes) : null;
                          },
                        );
                      },
                      errorBuilder: (context, error, stackTrace) =>
                          const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text.rich(
                    TextSpan(
                      style: const TextStyle(
                        fontFamily: 'GoogleSans',
                        color: AppTheme.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                      children: [
                        TextSpan(text: _greeting),
                        const TextSpan(
                          text: '.',
                          style: TextStyle(color: AppTheme.accent),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
