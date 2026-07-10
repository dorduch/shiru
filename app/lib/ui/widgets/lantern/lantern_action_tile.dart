import 'package:flutter/material.dart';
import '../../../theme/app_radius.dart';
import '../../../theme/app_typography.dart';
import '../../../theme/app_shadows.dart';
import '../../../theme/lantern_tokens.dart';

/// Big non-selectable action tile — the Lantern equivalent of `StTile`
/// (`lib/ui/widgets/storytime/st_tile.dart`), used for Home's two primary
/// tiles ("Make a Story" / "Listen").
///
/// Sizing (`minHeight` 140, `all(16)` padding), radius (`AppRadius.large`),
/// tap-scale interaction (`AnimatedScale` to 0.96) and `Semantics` wiring are
/// copied 1:1 from `StTile`'s current implementation — `StTile` itself does
/// not read `AppResponsive` (checked: no such usage in `st_tile.dart` today),
/// so there is no responsive sizing logic to carry over beyond what's here.
///
/// [emphasized] replaces `StTile`'s `big`/`color` combo with a binary
/// "is this the primary action" flag:
/// - `true` (e.g. "Make a Story"): `tokens.nightCard` fill plus the
///   lantern-glow `BoxShadow` lifted verbatim from `VoiceCard`'s
///   selected-state recipe (`voice_card.dart`) — glow, not a gradient fill,
///   since this tile isn't "selected," it's "the important one."
/// - `false` (e.g. "Listen"): plain `tokens.nightCard` fill with a
///   `tokens.hush` hairline border, no glow.
///
/// Both variants keep `AppShadows.card` as their base card shadow (shape,
/// not color — reused exactly as `StTile` already applies it); the glow is
/// layered on top for the emphasized variant rather than replacing it.
class LanternActionTile extends StatefulWidget {
  const LanternActionTile({
    super.key,
    required this.glyph,
    required this.title,
    required this.subtitle,
    this.emphasized = false,
    this.onTap,
  });

  /// Glyph/icon/sprite shown in the tile body.
  final Widget glyph;

  final String title;
  final String subtitle;

  /// Whether this is the primary action tile (gets the lantern glow).
  final bool emphasized;

  final VoidCallback? onTap;

  @override
  State<LanternActionTile> createState() => _LanternActionTileState();
}

class _LanternActionTileState extends State<LanternActionTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<LanternTokens>()!;

    final boxShadow = <BoxShadow>[
      ...AppShadows.card,
      if (widget.emphasized)
        BoxShadow(
          color: tokens.lantern.withValues(alpha: 0.22),
          blurRadius: 28,
          offset: const Offset(0, 6),
        ),
    ];

    return Semantics(
      button: true,
      label: '${widget.title}, ${widget.subtitle}',
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap?.call();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: Container(
            constraints: const BoxConstraints(minHeight: 140),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: tokens.nightCard,
              borderRadius: AppRadius.large,
              border: widget.emphasized
                  ? null
                  : Border.all(color: tokens.hush, width: 1),
              boxShadow: boxShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Expanded(
                  child: Center(child: widget.glyph),
                ),
                Text(
                  widget.title,
                  style: AppTypography.titleLarge.copyWith(color: tokens.moon),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.subtitle,
                  style: AppTypography.labelMedium
                      .copyWith(color: tokens.moonDim),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
