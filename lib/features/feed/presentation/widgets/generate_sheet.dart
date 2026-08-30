import 'package:flutter/material.dart';
import 'package:Skolar/core/theme/app_theme.dart';

class GenerateSheet extends StatefulWidget {
  const GenerateSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXxl),
        ),
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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.onboardingButtonBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'What do you want to practice?',
              style: TextStyle(
                fontFamily: 'GoogleSans',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.onBackground,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Type subject, year range & difficulty',
              style: TextStyle(
                fontFamily: 'GoogleSans',
                fontSize: 12,
                color: AppTheme.onBackground2,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(
                  color: AppTheme.onboardingButtonBorder,
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Row(
                children: [
                  const Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: AppTheme.accentPurple,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      style: const TextStyle(
                        fontFamily: 'GoogleSans',
                        fontSize: 14,
                        color: AppTheme.onBackground,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'DSA 2022-2025 hard…',
                        hintStyle: TextStyle(
                          fontFamily: 'GoogleSans',
                          color: AppTheme.onBackground2,
                          fontSize: 14,
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
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.accentPurple,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.send_rounded,
                            size: 14,
                            color: AppTheme.onPrimary,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Go',
                            style: TextStyle(
                              fontFamily: 'GoogleSans',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.onPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _chips.map((chip) {
                return GestureDetector(
                  onTap: () => _controller.text = chip,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                      border: Border.all(
                        color: AppTheme.onboardingButtonBorder,
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      chip,
                      style: const TextStyle(
                        fontFamily: 'GoogleSans',
                        fontSize: 11,
                        color: AppTheme.onBackground2,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
