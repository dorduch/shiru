import 'package:flutter/material.dart';

import '../../../models/audio_card.dart';
import '../../../models/sprites.dart';
import '../../concept_icons.dart';
import '../../pixel_sprite.dart';
import 'st_concept_token.dart';

/// Story tile/player artwork.
///
/// Any story whose [AudioCard.spriteKey] names a drawn [ConceptIcon] (curated
/// stories, and generated stories imported after [AudioCard.spriteKey] was
/// switched to store the story's theme name) renders the rich SVG glyph on a
/// transparent background, so the host (row avatar, grid art panel, player
/// hero) supplies the matching tint. Older generated cards whose spriteKey is
/// still a pixel-sprite id fall back to their narrator's concept icon when
/// one exists. Everything else (plain uploaded audio) keeps its pixel sprite.
/// Sharing one widget keeps the three render sites consistent.
class StoryAvatar extends StatelessWidget {
  const StoryAvatar({
    super.key,
    required this.card,
    this.conceptSize = 46,
    this.pixelScale = 3,
    this.isPlaying = false,
  });

  final AudioCard card;

  /// Rendered size (px) of the concept SVG glyph.
  final double conceptSize;

  /// `PixelSprite` scale used for the non-concept fallback.
  final double pixelScale;

  /// Whether narration is currently playing. Drives the `PixelSprite`
  /// fallback's animation state — active (pulsing) while playing, idle
  /// otherwise. Has no effect on the concept-SVG render path (static art).
  final bool isPlaying;

  @override
  Widget build(BuildContext context) {
    // a) spriteKey names a concept directly (curated stories, and generated
    //    stories imported with `spriteKey: theme.name`).
    // b) fall back to the narrator's concept icon — covers generated cards
    //    from before the spriteKey switch, whose spriteKey is an old pixel
    //    sprite id rather than a concept name.
    final concept = storyIconConceptByName(card.spriteKey) ??
        (card.narratorKey != null && conceptIconFor(card.narratorKey!) != null
            ? card.narratorKey
            : null);
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
      state: isPlaying ? SpriteState.active : SpriteState.idle,
    );
  }
}
