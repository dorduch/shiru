import 'package:flutter/material.dart';

import '../../../models/audio_card.dart';
import '../../../models/sprites.dart';
import '../../../models/storytime_models.dart';
import '../../concept_icons.dart';
import '../../pixel_sprite.dart';
import 'st_concept_token.dart';

/// Story tile/player artwork.
///
/// Curated stories whose [AudioCard.spriteKey] names a drawn [ConceptIcon]
/// render the rich SVG glyph on a transparent background, so the host (row
/// avatar, grid art panel, player hero) supplies the matching tint. Every other
/// card keeps its pixel sprite. Sharing one widget keeps the three render sites
/// consistent.
class StoryAvatar extends StatelessWidget {
  const StoryAvatar({
    super.key,
    required this.card,
    this.conceptSize = 46,
    this.pixelScale = 3,
  });

  final AudioCard card;

  /// Rendered size (px) of the concept SVG glyph.
  final double conceptSize;

  /// `PixelSprite` scale used for the non-concept fallback.
  final double pixelScale;

  @override
  Widget build(BuildContext context) {
    // Only curated stories opt into the rich SVG art — user/generated cards
    // keep their pixel sprite, so a future sprite key that happens to match a
    // concept name can never silently flip a user card to an SVG glyph.
    final concept = card.storyOrigin == StoryOrigin.curated
        ? storyIconConceptByName(card.spriteKey)
        : null;
    if (concept != null && conceptIconFor(concept) != null) {
      return StConceptToken(
        value: concept,
        emoji: '',
        iconSize: conceptSize,
        background: false,
      );
    }
    return PixelSprite(
      sprite: card.spriteKey != null
          ? (predefinedSprites[card.spriteKey!] ?? autoAssignSprite(card.title))
          : autoAssignSprite(card.title),
      scale: pixelScale,
    );
  }
}
