import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_radius.dart';
import '../../../theme/app_typography.dart';
import '../../../theme/app_shadows.dart';

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
    this.footer,
    this.tint,
  });

  final String name;
  final Widget thumbnail;
  final bool selected;
  final VoidCallback? onTap;

  /// Optional control rendered below the name, OUTSIDE the clipped thumbnail
  /// box (e.g. a narrator "Preview" button). Kept out of the thumbnail so it
  /// can't be clipped by the fixed-size art container.
  final Widget? footer;

  /// Optional concept tint that fills the whole card. When set, the icon's
  /// background and the card's background read as one seamless surface;
  /// selection is shown by the ember border + shadow rather than a bg swap.
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<StorytimeTokens>()!;

    final borderColor = selected ? tokens.ember : tokens.line;
    final borderWidth = selected ? 2.5 : 1.5;
    final bgColor = tint ??
        (selected
            ? const Color(0xFFFFF3EA) // warm ember tint
            : tokens.paper);
    final shadows = selected ? AppShadows.card : <BoxShadow>[];

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        // passthrough so the card keeps the grid cell's tight constraints
        // (fills the cell) and the badge positions within the cell bounds.
        fit: StackFit.passthrough,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            padding: const EdgeInsets.all(14),
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
                  // Inter (not the Nunito display face) for these small concept
                  // labels: friendlier and more legible at 14px than the display
                  // font, which is reserved for headings and story text.
                  style: AppTypography.bodyLarge.copyWith(
                    fontSize: 14,
                    color: tokens.ink,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (footer != null) ...[const SizedBox(height: 6), footer!],
              ],
            ),
          ),
          // Selection check badge — a non-color-dependent affordance so
          // selection reads for color-blind users (the ember ring alone relied
          // on hue). Dark check on ember clears ~6.6:1.
          if (selected)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: tokens.ember,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_rounded, size: 15, color: tokens.onAccent),
              ),
            ),
        ],
      ),
    );
  }
}
