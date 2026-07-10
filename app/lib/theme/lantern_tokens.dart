import 'package:flutter/material.dart';

// ─── ThemeExtension ───────────────────────────────────────────────────────────

/// "Lantern" design tokens — a from-scratch, dark-first visual language for
/// the redesigned story-creation screen (the "Composer") and, progressively,
/// the rest of the kid-facing app.
///
/// Coexists with [StorytimeTokens]; it does not replace it. Retrieve at
/// runtime via:
///
/// ```dart
/// final lantern = Theme.of(context).extension<LanternTokens>()!;
/// ```
///
/// See `docs/superpowers/specs/2026-07-10-story-composer-design.md` §4.2 for
/// the canonical palette this class mirrors.
@immutable
class LanternTokens extends ThemeExtension<LanternTokens> {
  const LanternTokens({
    required this.nightDeep,
    required this.nightMid,
    required this.nightCard,
    required this.lantern,
    required this.lanternDeep,
    required this.moon,
    required this.moonDim,
    required this.moonFaint,
    required this.hush,
    required this.hueSun,
    required this.hueSky,
    required this.hueBlossom,
    required this.hueLilac,
    required this.hueMeadow,
    required this.hueCoral,
    required this.ctaGradient,
    required this.nightGradient,
  });

  // ─── Grounds ──────────────────────────────────────────────────────────────
  /// Screen ground, bottom of gradient (night `#141227`; day `#FDF7EC`).
  final Color nightDeep;

  /// Screen ground, top of gradient / sheet ground (night `#211E3F`; day
  /// `#FDF7EC`).
  final Color nightMid;

  /// Card / surface fill (night `#2B2750`; day `#FFFFFF`).
  final Color nightCard;

  // ─── Accent ───────────────────────────────────────────────────────────────
  /// Primary accent — CTA, selection rings, glow (`#FFB566`). Shared across
  /// both themes.
  final Color lantern;

  /// Accent gradient end, pressed states (`#E8834A`). Shared across both
  /// themes.
  final Color lanternDeep;

  // ─── Text ─────────────────────────────────────────────────────────────────
  /// Primary text (night `#FFF3DC`; day `#2A2440`).
  final Color moon;

  /// Secondary text (night `#C9C2E0`; day `#5E5877`).
  final Color moonDim;

  /// Tertiary / disabled text (night `#8B84AD`; day `#A29BC0`).
  final Color moonFaint;

  // ─── Lines ────────────────────────────────────────────────────────────────
  /// Hairlines, dividers, inactive tracks (night `#3A3566`; day `#EBE3D6`).
  final Color hush;

  // ─── Concept hues ─────────────────────────────────────────────────────────
  // Slot tints — used as fills behind glyphs, never as text. Shared across
  // both themes; only the fill opacity differs (see [slotFillFor]).
  /// Hero slot (`#FFD479`).
  final Color hueSun;

  /// Where slot (`#7FB5F0`).
  final Color hueSky;

  /// About slot (`#F2A7C3`).
  final Color hueBlossom;

  /// What-happens slot (`#B9A5F5`).
  final Color hueLilac;

  /// Success / ready states (`#7ED4A6`).
  final Color hueMeadow;

  /// Errors / destructive (`#FF8E7A`).
  final Color hueCoral;

  // ─── Gradients ────────────────────────────────────────────────────────────
  /// Primary CTA gradient — `lantern → lanternDeep`, horizontal
  /// (centerLeft → centerRight). Shared across both themes.
  final LinearGradient ctaGradient;

  /// Screen-ground gradient — `nightMid → nightDeep`, top → bottom.
  final LinearGradient nightGradient;

  // ─── Helpers ──────────────────────────────────────────────────────────────
  /// Slot card fill for a concept [hue]: dimmed to 24% on the night ground so
  /// the screen stays dim-room-friendly (the glyph itself stays full-strength
  /// on top of the fill), full-strength on the Daylight theme.
  Color slotFillFor(Color hue, {required bool night}) {
    return night ? hue.withValues(alpha: 0.24) : hue;
  }

  // ─── Named palettes ───────────────────────────────────────────────────────
  /// Primary/default palette — dark-first "night" ground. Used by the kid
  /// flow (Composer) regardless of system theme.
  const LanternTokens.night()
      : this(
          nightDeep: const Color(0xFF141227),
          nightMid: const Color(0xFF211E3F),
          nightCard: const Color(0xFF2B2750),
          lantern: const Color(0xFFFFB566),
          lanternDeep: const Color(0xFFE8834A),
          moon: const Color(0xFFFFF3DC),
          moonDim: const Color(0xFFC9C2E0),
          moonFaint: const Color(0xFF8B84AD),
          hush: const Color(0xFF3A3566),
          hueSun: const Color(0xFFFFD479),
          hueSky: const Color(0xFF7FB5F0),
          hueBlossom: const Color(0xFFF2A7C3),
          hueLilac: const Color(0xFFB9A5F5),
          hueMeadow: const Color(0xFF7ED4A6),
          hueCoral: const Color(0xFFFF8E7A),
          ctaGradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFFFFB566), Color(0xFFE8834A)],
          ),
          nightGradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF211E3F), Color(0xFF141227)],
          ),
        );

  /// Daylight variant — parent-zone screens and an eventual user toggle.
  /// `lantern`/`lanternDeep`/the concept hues are unchanged from [night];
  /// only grounds, text and lines flip to light-surface values.
  const LanternTokens.day()
      : this(
          nightDeep: const Color(0xFFFDF7EC),
          nightMid: const Color(0xFFFDF7EC),
          nightCard: const Color(0xFFFFFFFF),
          lantern: const Color(0xFFFFB566),
          lanternDeep: const Color(0xFFE8834A),
          moon: const Color(0xFF2A2440),
          moonDim: const Color(0xFF5E5877),
          moonFaint: const Color(0xFFA29BC0),
          hush: const Color(0xFFEBE3D6),
          hueSun: const Color(0xFFFFD479),
          hueSky: const Color(0xFF7FB5F0),
          hueBlossom: const Color(0xFFF2A7C3),
          hueLilac: const Color(0xFFB9A5F5),
          hueMeadow: const Color(0xFF7ED4A6),
          hueCoral: const Color(0xFFFF8E7A),
          ctaGradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFFFFB566), Color(0xFFE8834A)],
          ),
          nightGradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFDF7EC), Color(0xFFFDF7EC)],
          ),
        );

  // ─── ThemeExtension boilerplate ───────────────────────────────────────────
  @override
  LanternTokens copyWith({
    Color? nightDeep,
    Color? nightMid,
    Color? nightCard,
    Color? lantern,
    Color? lanternDeep,
    Color? moon,
    Color? moonDim,
    Color? moonFaint,
    Color? hush,
    Color? hueSun,
    Color? hueSky,
    Color? hueBlossom,
    Color? hueLilac,
    Color? hueMeadow,
    Color? hueCoral,
    LinearGradient? ctaGradient,
    LinearGradient? nightGradient,
  }) {
    return LanternTokens(
      nightDeep: nightDeep ?? this.nightDeep,
      nightMid: nightMid ?? this.nightMid,
      nightCard: nightCard ?? this.nightCard,
      lantern: lantern ?? this.lantern,
      lanternDeep: lanternDeep ?? this.lanternDeep,
      moon: moon ?? this.moon,
      moonDim: moonDim ?? this.moonDim,
      moonFaint: moonFaint ?? this.moonFaint,
      hush: hush ?? this.hush,
      hueSun: hueSun ?? this.hueSun,
      hueSky: hueSky ?? this.hueSky,
      hueBlossom: hueBlossom ?? this.hueBlossom,
      hueLilac: hueLilac ?? this.hueLilac,
      hueMeadow: hueMeadow ?? this.hueMeadow,
      hueCoral: hueCoral ?? this.hueCoral,
      ctaGradient: ctaGradient ?? this.ctaGradient,
      nightGradient: nightGradient ?? this.nightGradient,
    );
  }

  @override
  LanternTokens lerp(LanternTokens? other, double t) {
    if (other == null) return this;
    return LanternTokens(
      nightDeep: Color.lerp(nightDeep, other.nightDeep, t)!,
      nightMid: Color.lerp(nightMid, other.nightMid, t)!,
      nightCard: Color.lerp(nightCard, other.nightCard, t)!,
      lantern: Color.lerp(lantern, other.lantern, t)!,
      lanternDeep: Color.lerp(lanternDeep, other.lanternDeep, t)!,
      moon: Color.lerp(moon, other.moon, t)!,
      moonDim: Color.lerp(moonDim, other.moonDim, t)!,
      moonFaint: Color.lerp(moonFaint, other.moonFaint, t)!,
      hush: Color.lerp(hush, other.hush, t)!,
      hueSun: Color.lerp(hueSun, other.hueSun, t)!,
      hueSky: Color.lerp(hueSky, other.hueSky, t)!,
      hueBlossom: Color.lerp(hueBlossom, other.hueBlossom, t)!,
      hueLilac: Color.lerp(hueLilac, other.hueLilac, t)!,
      hueMeadow: Color.lerp(hueMeadow, other.hueMeadow, t)!,
      hueCoral: Color.lerp(hueCoral, other.hueCoral, t)!,
      ctaGradient: LinearGradient.lerp(ctaGradient, other.ctaGradient, t)!,
      nightGradient:
          LinearGradient.lerp(nightGradient, other.nightGradient, t)!,
    );
  }
}
