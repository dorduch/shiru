import 'package:flutter/material.dart';
import '../../../theme/app_radius.dart';
import '../../../theme/app_typography.dart';
import '../../../theme/lantern_tokens.dart';

/// Lantern equivalent of `StTextField`
/// (`lib/ui/widgets/storytime/st_text_field.dart`) — shape/spacing/radius
/// copied 1:1, only the token source changes: `nightCard` fill (was `paper`),
/// `hush` border (was `line2`), `lantern` focus border (was `ember`), `moon`/
/// `moonDim`/`moonFaint` text (was `ink`/`ink2`/`ink3`).
class LanternTextField extends StatelessWidget {
  const LanternTextField({
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
    final tokens = Theme.of(context).extension<LanternTokens>()!;

    final border = OutlineInputBorder(
      borderRadius: AppRadius.small,
      borderSide: BorderSide(color: tokens.hush, width: 1.5),
    );

    final focusedBorder = OutlineInputBorder(
      borderRadius: AppRadius.small,
      borderSide: BorderSide(color: tokens.lantern, width: 1.5),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: AppTypography.labelLarge.copyWith(color: tokens.moonDim),
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
          style: AppTypography.inputText.copyWith(color: tokens.moon),
          cursorColor: tokens.lantern,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTypography.inputText.copyWith(color: tokens.moonFaint),
            filled: true,
            fillColor: tokens.nightCard,
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
