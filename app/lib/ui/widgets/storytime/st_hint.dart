import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_radius.dart';
import '../../../theme/app_typography.dart';
import '../../../theme/app_colors.dart';

/// Warm advisory hint note.
///
/// Uses a soft gold/cream background with rounded corners.
/// Optionally shows a leading icon.
///
/// ```dart
/// StHint(text: 'Speak clearly and at a normal pace for best results.')
/// ```
class StHint extends StatelessWidget {
  const StHint({
    super.key,
    required this.text,
    this.icon = Icons.lightbulb_outline_rounded,
  });

  final String text;

  /// Icon shown at the leading edge. Pass `null` to omit.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<StorytimeTokens>()!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8EC), // warm gold tint
        borderRadius: AppRadius.medium,
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.45), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, color: AppColors.gold, size: 18),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              text,
              style: AppTypography.labelMedium.copyWith(color: tokens.ink2),
            ),
          ),
        ],
      ),
    );
  }
}
