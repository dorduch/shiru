import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_typography.dart';
import '../../../theme/app_colors.dart';

/// Recurring three-line section header: eyebrow + title + optional subtitle.
///
/// ```dart
/// StSectionHeader(
///   eyebrow: 'STEP 1',
///   title: 'Choose a character',
///   sub: 'Who will star in this story?',
/// )
/// ```
class StSectionHeader extends StatelessWidget {
  const StSectionHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.sub,
    this.centerAlign = false,
  });

  final String title;
  final String? eyebrow;
  final String? sub;
  final bool centerAlign;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<StorytimeTokens>()!;
    final align =
        centerAlign ? TextAlign.center : TextAlign.start;
    final cross = centerAlign
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;

    return Column(
      crossAxisAlignment: cross,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (eyebrow != null) ...[
          Text(
            eyebrow!.toUpperCase(),
            style: AppTypography.eyebrow.copyWith(
              color: AppColors.accent2,
            ),
            textAlign: align,
          ),
          const SizedBox(height: 4),
        ],
        Text(
          title,
          style: AppTypography.headlineSmall.copyWith(color: tokens.ink),
          textAlign: align,
        ),
        if (sub != null) ...[
          const SizedBox(height: 4),
          Text(
            sub!,
            style: AppTypography.bodySmall.copyWith(color: tokens.ink2),
            textAlign: align,
          ),
        ],
      ],
    );
  }
}
