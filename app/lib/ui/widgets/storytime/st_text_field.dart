import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_radius.dart';
import '../../../theme/app_typography.dart';

/// Storytime text input field.
///
/// Wraps [TextFormField] in the Storytime visual language:
/// paper background, line2 border, 14-radius corners, Inter body text.
///
/// For a static "empty field" placeholder (e.g. in a mock or locked state),
/// use [StField].
class StTextField extends StatelessWidget {
  const StTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.onChanged,
    this.obscureText = false,
    this.keyboardType,
    this.autofocus = false,
    this.maxLines = 1,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final ValueChanged<String>? onChanged;
  final bool obscureText;
  final TextInputType? keyboardType;
  final bool autofocus;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<StorytimeTokens>()!;

    final border = OutlineInputBorder(
      borderRadius: AppRadius.small,
      borderSide: BorderSide(color: tokens.line2, width: 1.5),
    );

    final focusedBorder = OutlineInputBorder(
      borderRadius: AppRadius.small,
      borderSide: BorderSide(color: tokens.ember, width: 1.5),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: AppTypography.labelLarge.copyWith(color: tokens.ink2),
          ),
          const SizedBox(height: 6),
        ],
        TextFormField(
          controller: controller,
          onChanged: onChanged,
          obscureText: obscureText,
          keyboardType: keyboardType,
          autofocus: autofocus,
          maxLines: maxLines,
          style: AppTypography.inputText.copyWith(color: tokens.ink),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTypography.inputText.copyWith(color: tokens.ink3),
            filled: true,
            fillColor: tokens.paper,
            border: border,
            enabledBorder: border,
            focusedBorder: focusedBorder,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }
}

/// A static, non-interactive empty field placeholder.
///
/// Used in gallery / locked-state previews where [StTextField] with a
/// controller is not needed.
class StField extends StatelessWidget {
  const StField({
    super.key,
    this.placeholder = '',
    this.label,
  });

  final String placeholder;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<StorytimeTokens>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: AppTypography.labelLarge.copyWith(color: tokens.ink2),
          ),
          const SizedBox(height: 6),
        ],
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: tokens.paper,
            borderRadius: AppRadius.small,
            border: Border.all(color: tokens.line2, width: 1.5),
          ),
          child: Text(
            placeholder,
            style: AppTypography.inputText.copyWith(color: tokens.ink3),
          ),
        ),
      ],
    );
  }
}
