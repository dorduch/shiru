import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Lantern-lit family-voice glyph — replaces the 🎙 emoji everywhere a family
/// voice renders (Voice Shelf card, Slot Sheet, etc).
///
/// See `docs/superpowers/specs/2026-07-10-story-composer-design.md` §4.5
/// "Family-voice glyph": *"a soft lantern-lit profile silhouette with a
/// small sound-wave arc, drawn in the existing icon grammar (48 viewBox,
/// single outline + 2 fills)"*.
///
/// Rendered the same way the existing 30-piece concept-icon set is (inline
/// SVG string via `flutter_svg`'s `SvgPicture.string` — see
/// `lib/ui/concept_icons.dart` / `lib/ui/widgets/storytime/st_concept_token.dart`)
/// rather than adding a new rendering path or a new dependency (`flutter_svg`
/// is already in `pubspec.yaml`).
///
/// This is placeholder-quality art — a simple rounded profile + two sound
/// wave arcs — not a pixel-perfect illustration. Prioritizes compiling and
/// reading reasonably at small card sizes over precision.
class FamilyVoiceGlyph extends StatelessWidget {
  const FamilyVoiceGlyph({super.key, this.size = 46});

  /// Rendered width/height (square). Defaults to 46, matching the ~48
  /// viewBox at roughly 1:1 scale.
  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(
      _svg,
      width: size,
      height: size,
    );
  }
}

/// Inline SVG, viewBox `0 0 48 48`. Single `#241F3D` outline (night-legible
/// ink, matching the recolored concept-glyph set) + two warm fills: a soft
/// lantern-gold face (`#F6C97A`) with an ember cheek accent (`#E8834A`), and
/// a `#FFB566` (lantern) sound-wave arc pair trailing off the profile's
/// "mouth" to suggest a voice being carried/read aloud.
const String _svg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">'
    '<path d="M18 8 C11 8 6 14 6 21 C6 26 9 30 13 32 L13 40 '
    'C13 41.5 14.5 42.5 16 42 L22 39.5 C29 39 34 32.5 34 24 C34 15 27 8 18 8 Z" '
    'fill="#F6C97A" stroke="#241F3D" stroke-width="2" stroke-linejoin="round"/>'
    '<circle cx="15" cy="24" r="2.4" fill="#E8834A" stroke="#241F3D" stroke-width="1"/>'
    '<path d="M37 17 a10 10 0 0 1 0 14" fill="none" stroke="#FFB566" '
    'stroke-width="2.4" stroke-linecap="round"/>'
    '<path d="M41.5 13.5 a16 16 0 0 1 0 21" fill="none" stroke="#FFB566" '
    'stroke-width="2.2" stroke-linecap="round" opacity="0.7"/>'
    '</svg>';
