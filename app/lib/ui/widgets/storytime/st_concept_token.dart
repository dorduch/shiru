import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../theme/app_colors.dart';
import '../../concept_icons.dart';

/// A story-vocabulary concept (character / scene / theme / plot / narrator)
/// rendered as a rich SVG glyph seated on its warm, cream-based tint token.
///
/// Pass the enum [value] (e.g. `StoryCharacter.prince`) and the [emoji]
/// fallback. If a hand-drawn icon exists it renders the colorful glyph on its
/// themed tint; otherwise it falls back to the emoji on a neutral cream token,
/// so every tile reads as a consistent token while the icon set is completed.
class StConceptToken extends StatelessWidget {
  const StConceptToken({
    super.key,
    required this.value,
    required this.emoji,
    this.iconSize = 46,
    this.fill = true,
    this.background = true,
  });

  /// The story-vocabulary enum value, or null to force the emoji fallback.
  final Object? value;

  /// Emoji shown when no rich icon is drawn yet.
  final String emoji;

  /// Rendered glyph size (px).
  final double iconSize;

  /// When true the token tint fills the available box; when false the token
  /// is intrinsic-sized (used in the compact review row).
  final bool fill;

  /// When false the glyph renders on a transparent background, so the host
  /// card supplies the (matching) tint and the two backgrounds read as one.
  final bool background;

  @override
  Widget build(BuildContext context) {
    final icon = value == null ? null : conceptIconFor(value!);
    final tint = icon?.tint ?? AppColors.cream;

    final glyph = icon != null
        ? SvgPicture.string(icon.svg, width: iconSize, height: iconSize)
        : Text(emoji, style: TextStyle(fontSize: iconSize * 0.82));

    if (!background) {
      return fill
          ? Center(child: glyph)
          : SizedBox(width: iconSize + 16, height: iconSize + 16, child: Center(child: glyph));
    }
    if (fill) {
      return Container(color: tint, alignment: Alignment.center, child: glyph);
    }
    return Container(
      width: iconSize + 16,
      height: iconSize + 16,
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: glyph,
    );
  }
}
