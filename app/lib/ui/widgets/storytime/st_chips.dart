import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_radius.dart';
import '../../../theme/app_typography.dart';
import '../../../theme/app_colors.dart';

/// Generic small status/label chip.
///
/// ```dart
/// StChip(label: 'New')
/// StChip(label: 'Draft', color: AppColors.ink2)
/// ```
class StChip extends StatelessWidget {
  const StChip({
    super.key,
    required this.label,
    this.color,
    this.onTap,
  });

  final String label;

  /// Fill color. Defaults to a soft cream tint.
  final Color? color;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<StorytimeTokens>()!;
    final bg = color ?? tokens.line;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: AppRadius.full,
        ),
        child: Text(
          label,
          style: AppTypography.labelLarge.copyWith(color: tokens.ink),
        ),
      ),
    );
  }
}

// ─── ToneChip ────────────────────────────────────────────────────────────────

/// A selectable narrator tone chip (e.g. "Spooky", "Gentle", "Silly").
class StToneChip extends StatelessWidget {
  const StToneChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<StorytimeTokens>()!;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? tokens.ember : tokens.paper,
          borderRadius: AppRadius.full,
          border: Border.all(
            color: selected ? tokens.ember : tokens.line,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.labelLarge.copyWith(
            color: selected ? Colors.white : tokens.ink2,
          ),
        ),
      ),
    );
  }
}

// ─── LockPill ────────────────────────────────────────────────────────────────

/// "Family plan" lock pill — shown on Family-tier locked features.
class StLockPill extends StatelessWidget {
  const StLockPill({super.key, this.label = 'Family'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.night2,
        borderRadius: AppRadius.full,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_outline_rounded,
              color: AppColors.gold, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.labelLarge.copyWith(color: AppColors.gold),
          ),
        ],
      ),
    );
  }
}

// ─── SoonTag ─────────────────────────────────────────────────────────────────

/// "Coming soon" tag — shown for unimplemented future features.
class StSoonTag extends StatelessWidget {
  const StSoonTag({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<StorytimeTokens>()!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tokens.gold.withValues(alpha: 0.18),
        borderRadius: AppRadius.full,
      ),
      child: Text(
        'Soon',
        style: AppTypography.labelLarge.copyWith(color: AppColors.dusk),
      ),
    );
  }
}
