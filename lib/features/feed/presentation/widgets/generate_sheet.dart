import 'package:flutter/material.dart';
import 'feed_colors.dart';

class GenerateSheet extends StatefulWidget {
  const GenerateSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: FeedColors.sheetBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: const GenerateSheet(),
      ),
    );
  }

  @override
  State<GenerateSheet> createState() => _GenerateSheetState();
}

class _GenerateSheetState extends State<GenerateSheet> {
  final _controller = TextEditingController();

  static const _chips = [
    'DSA 2022-2025 hard',
    'OS 2021-2024 medium',
    'CN 2023-2025 easy',
    'DBMS 2020-2024 hard',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _generate() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    Navigator.pop(context);
    // TODO: pass text to AI generation use case
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 32,
              height: 3,
              decoration: BoxDecoration(
                color: FeedColors.sheetHandle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'What do you want to practice?',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: FeedColors.textSecondary,
              fontFamily: 'DM Sans',
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Type subject, year range & difficulty',
            style: TextStyle(
              fontSize: 11,
              color: FeedColors.textHint,
              fontFamily: 'DM Sans',
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: FeedColors.inputBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: FeedColors.borderTag, width: 0.5),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
            child: Row(
              children: [
                const Icon(
                  Icons.edit_outlined,
                  size: 15,
                  color: FeedColors.textHint,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    style: const TextStyle(
                      fontSize: 13,
                      color: FeedColors.textPrimary,
                      fontFamily: 'DM Sans',
                    ),
                    decoration: const InputDecoration(
                      hintText: 'DSA 2022-2025 hard…',
                      hintStyle: TextStyle(
                        color: Color(0xFF383940),
                        fontFamily: 'DM Sans',
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onSubmitted: (_) => _generate(),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _generate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: FeedColors.purpleDark,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.send_rounded,
                          size: 13,
                          color: FeedColors.textPrimary,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Go',
                          style: TextStyle(
                            fontSize: 12,
                            color: FeedColors.textPrimary,
                            fontFamily: 'DM Sans',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 5,
            runSpacing: 6,
            children: _chips.map((chip) {
              return GestureDetector(
                onTap: () => _controller.text = chip,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: FeedColors.tagBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: FeedColors.borderTag, width: 0.5),
                  ),
                  child: Text(
                    chip,
                    style: const TextStyle(
                      fontSize: 11,
                      color: FeedColors.textMuted,
                      fontFamily: 'DM Sans',
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
