import 'package:flutter/material.dart';
import 'package:Skolar/core/theme/app_theme.dart';

/// A labelled input field with a leading icon, styled for the light sheet
/// of the auth preview screen. Visual only — no real validation rules.
class PreviewTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool isPassword;
  final TextInputType keyboardType;
  final String? errorText;

  const PreviewTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.errorText,
  });

  @override
  State<PreviewTextField> createState() => _PreviewTextFieldState();
}

class _PreviewTextFieldState extends State<PreviewTextField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null;
    final borderColor = hasError ? AppTheme.wishlist : Colors.transparent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            fontFamily: 'GoogleSans',
            color: AppTheme.onSurfaceDark,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppTheme.sm),
        TextField(
          controller: widget.controller,
          obscureText: widget.isPassword && _obscure,
          keyboardType: widget.keyboardType,
          style: const TextStyle(
            fontFamily: 'GoogleSans',
            color: AppTheme.onSurfaceDark,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: const TextStyle(
              fontFamily: 'GoogleSans',
              color: AppTheme.sheetTextSecondary,
              fontSize: 14,
            ),
            prefixIcon: Icon(
              widget.icon,
              color: AppTheme.sheetTextSecondary,
              size: 20,
            ),
            suffixIcon: widget.isPassword
                ? IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppTheme.sheetTextSecondary,
                      size: 20,
                    ),
                  )
                : null,
            filled: true,
            fillColor: AppTheme.sheetFieldFill,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              borderSide: BorderSide(color: borderColor, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              borderSide: BorderSide(
                color: hasError ? AppTheme.wishlist : AppTheme.accentPurple,
                width: 2,
              ),
            ),
            errorText: widget.errorText,
            errorStyle: const TextStyle(
              fontFamily: 'GoogleSans',
              color: AppTheme.wishlist,
              fontSize: 11,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppTheme.md,
              vertical: AppTheme.smd,
            ),
          ),
        ),
      ],
    );
  }
}
