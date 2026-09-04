import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:Skolar/core/theme/app_theme.dart';

class NovaChatInputDock extends StatefulWidget {
  final ValueChanged<String> onSendMessage;
  final ValueChanged<bool> onFocusChanged;
  final ValueChanged<bool>? onHasTextChanged;
  final bool isThinking;

  const NovaChatInputDock({
    super.key,
    required this.onSendMessage,
    required this.onFocusChanged,
    this.onHasTextChanged,
    this.isThinking = false,
  });

  @override
  State<NovaChatInputDock> createState() => _NovaChatInputDockState();
}

class _NovaChatInputDockState extends State<NovaChatInputDock> {
  late final TextEditingController _textCtrl;
  late final FocusNode _focusNode;
  bool _sendBtnPressed = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController()
      ..addListener(() {
        final hasText = _textCtrl.text.trim().isNotEmpty;
        if (hasText != _hasText) {
          _hasText = hasText;
          widget.onHasTextChanged?.call(hasText);
        }
      });
    _focusNode = FocusNode()
      ..addListener(() {
        widget.onFocusChanged(_focusNode.hasFocus);
      });
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void setInputText(String text) {
    _textCtrl.text = text;
    _textCtrl.selection = TextSelection.fromPosition(
      TextPosition(offset: text.length),
    );
    _focusNode.requestFocus();
  }

  void _handleSend() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || widget.isThinking) return;
    _textCtrl.clear();
    _focusNode.unfocus();
    FocusScope.of(context).unfocus();
    widget.onSendMessage(text);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            // High transparency glassmorphic dock
            color: Colors.black.withValues(alpha: 0.35),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.06),
                width: 1,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SafeArea(
            top: false,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF14141A).withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.14),
                  width: 1.0,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Text Field with "Send message..." hint
                  Expanded(
                    child: TextField(
                      controller: _textCtrl,
                      focusNode: _focusNode,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _handleSend(),
                      style: GoogleFonts.googleSans(
                        color: Colors.white,
                        fontSize: 15,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Send message...',
                        hintStyle: GoogleFonts.googleSans(
                          color: const Color(0xFF7A7A84),
                          fontSize: 15,
                        ),
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // 2.5D Tactile Chunky Send Button
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _textCtrl,
                    builder: (context, value, _) {
                      final hasText = value.text.trim().isNotEmpty;

                      if (widget.isThinking) {
                        return const Padding(
                          padding: EdgeInsets.all(8),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.accentPurple,
                            ),
                          ),
                        );
                      }

                      return GestureDetector(
                        onTapDown: hasText
                            ? (_) => setState(() => _sendBtnPressed = true)
                            : null,
                        onTapUp: hasText
                            ? (_) => setState(() => _sendBtnPressed = false)
                            : null,
                        onTapCancel: hasText
                            ? () => setState(() => _sendBtnPressed = false)
                            : null,
                        onTap: hasText ? _handleSend : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          transform: _sendBtnPressed && hasText
                              ? Matrix4.translationValues(0, 3, 0)
                              : Matrix4.identity(),
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: hasText
                                ? AppTheme.accentPurple
                                : Colors.white.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                            boxShadow: hasText && !_sendBtnPressed
                                ? const [
                                    BoxShadow(
                                      color: AppTheme.accentPurpleDark,
                                      offset: Offset(0, 3),
                                      blurRadius: 0,
                                    ),
                                  ]
                                : [],
                          ),
                          child: Icon(
                            Icons.arrow_upward_rounded,
                            color: hasText
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.3),
                            size: 20,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
