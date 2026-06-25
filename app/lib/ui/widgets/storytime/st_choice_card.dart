import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_radius.dart';
import '../../../theme/app_typography.dart';
import '../../../theme/app_shadows.dart';
import '../../../theme/app_colors.dart';

/// Selectable choice card used in the story wizard
/// (character / scene / theme / twist).
///
/// Pass any widget as [thumbnail] — typically a [PixelSprite] scaled to fit.
/// The card switches to an ember-border + warm-tint selected state when
/// [selected] is true.
class StChoiceCard extends StatelessWidget {
  const StChoiceCard({
    super.key,
    required this.name,
    required this.thumbnail,
    this.selected = false,
    this.onTap,
  });

  final String name;
  final Widget thumbnail;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<StorytimeTokens>()!;

    final borderColor = selected ? tokens.ember : tokens.line;
    final borderWidth = selected ? 2.0 : 1.5;
    final bgColor = selected
        ? const Color(0xFFFFF3EA) // warm ember tint
        : tokens.paper;
    final shadows = selected ? AppShadows.card : <BoxShadow>[];

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: AppRadius.medium,
          border: Border.all(color: borderColor, width: borderWidth),
          boxShadow: shadows,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Thumbnail area — fixed square container
            ClipRRect(
              borderRadius: AppRadius.small,
              child: SizedBox(
                width: 72,
                height: 72,
                child: thumbnail,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              style: AppTypography.titleLarge.copyWith(
                fontSize: 14,
                color: selected ? AppColors.dusk : tokens.ink,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
