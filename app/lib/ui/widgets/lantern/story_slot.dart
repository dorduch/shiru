import 'package:flutter/material.dart';
import '../../../theme/app_radius.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/lantern_tokens.dart';

/// One cell in the Composer's 2×2 story-concept grid (Hero / Where / About /
/// What-happens).
///
/// A slot always holds a value — unlike [VoiceCard], it never uses the
/// ring/check-badge selection vocabulary (spec §4.5, "StorySlot"). The only
/// two states are "suggested" (auto-filled by shuffle, not yet touched by the
/// child) and "chosen" (full opacity, no refresh mark).
///
/// Follows the seamless-surface rule: [glyph] renders with no background of
/// its own, and this card supplies the tint via [hueFill]. The caller is
/// responsible for resolving [hueFill] through
/// `LanternTokens.slotFillFor(hue, night: true)` before passing it in — this
/// widget just paints it as the card's solid background.
class StorySlot extends StatelessWidget {
  const StorySlot({
    super.key,
    required this.label,
    required this.valueName,
    required this.glyph,
    required this.hueFill,
    this.suggested = false,
    this.onTap,
  });

  /// The slot's category name, e.g. "HERO". Rendered uppercase.
  final String label;

  /// The currently chosen concept's display name, e.g. "A brave lion".
  final String valueName;

  /// The concept icon widget — transparent background; this card supplies
  /// the tint.
  final Widget glyph;

  /// This slot's resolved fill color (already alpha-adjusted by the caller
  /// via `LanternTokens.slotFillFor`).
  final Color hueFill;

  /// True when this slot was auto-filled by shuffle and hasn't been touched
  /// by the child yet. Renders the whole card dimmed with a small refresh
  /// mark; does not change on its own — the hosting screen promotes it to
  /// `false` once the child interacts with the slot.
  final bool suggested;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<LanternTokens>()!;

    final content = DecoratedBox(
      decoration: BoxDecoration(
        color: hueFill,
        borderRadius: AppRadius.large,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg - 2),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: tokens.moon.withValues(alpha: 0.75),
                  ),
                ),
                if (suggested)
                  Positioned(
                    top: -2,
                    right: 0,
                    child: Icon(
                      Icons.refresh_rounded,
                      size: 16,
                      color: tokens.moon.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ),
            Expanded(
              child: Center(
                child: SizedBox(width: 56, height: 56, child: glyph),
              ),
            ),
            Text(
              valueName,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: tokens.moon,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );

    return Semantics(
      button: true,
      label: '$label, $valueName',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: suggested ? Opacity(opacity: 0.85, child: content) : content,
      ),
    );
  }
}
