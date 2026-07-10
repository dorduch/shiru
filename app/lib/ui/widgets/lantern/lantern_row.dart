import 'package:flutter/material.dart';
import '../../../theme/app_radius.dart';
import '../../../theme/app_typography.dart';
import '../../../theme/lantern_tokens.dart';

/// Generic Lantern list row: leading slot (avatar/icon/glyph) + title +
/// optional subtitle + optional trailing slot (chevron / pill / tag).
///
/// The Lantern equivalent of `StRow` (`lib/ui/widgets/storytime/st_row.dart`)
/// — shape/spacing copied 1:1 (16h/12v padding, `AppRadius.large`), only the
/// token source changes (`StorytimeTokens` → `LanternTokens`). Unlike `StRow`,
/// [leading] is a fully generic widget rather than avatar-specific params
/// (`avatarInitial`/`avatarColor`/`avatarImage`/`avatarChild`) — this is the
/// shared row used across ~6 different screens (dashboard nav, account
/// settings, voice lists, story lists, the resume strip), so callers supply
/// whatever leading visual fits (a `CircleAvatar`, a concept icon, a
/// `PixelSprite`, a plain `Icon`) rather than being constrained to StRow's
/// circular-avatar-only shape.
///
/// Adds a `tokens.hush` hairline border (StRow has none) since Lantern rows
/// commonly sit directly on the night ground rather than on a paper surface
/// that already separates itself by color alone.
class LanternRow extends StatelessWidget {
  const LanternRow({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  /// Leading visual — avatar, icon, concept glyph, sprite, etc.
  final Widget leading;

  final String title;
  final String? subtitle;

  /// Widget placed at the trailing edge (chevron, pill, tag, etc.).
  final Widget? trailing;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<LanternTokens>()!;
    final label = subtitle == null ? title : '$title, $subtitle';

    return Semantics(
      button: onTap != null,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: tokens.nightCard,
            borderRadius: AppRadius.large,
            border: Border.all(color: tokens.hush, width: 1),
          ),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: AppTypography.titleLarge.copyWith(
                        fontSize: 16,
                        color: tokens.moon,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: AppTypography.labelMedium
                            .copyWith(color: tokens.moonDim),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
