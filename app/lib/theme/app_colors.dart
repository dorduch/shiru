import 'package:flutter/material.dart';

/// Storytime color palette.
///
/// Canonical source — derived from the Storytime wireframes (§4.1 of the
/// MVP plan).  All tokens are `const Color` so they can be used in const
/// widget constructors and decoration fields.
///
/// Two surface modes:
///   • **day** — cream/paper backgrounds, ink text, ember primary action.
///   • **bedtime** — night-gradient backgrounds, cream text, gold accents.
///
/// Legacy Shiru field names are preserved as aliases at the bottom of the
/// class so that callers that haven't been re-skinned yet continue to compile
/// without modification.
class AppColors {
  AppColors._();

  // ─── Night gradient ("bedtime" mode) ──────────────────────────────────────
  /// Deepest night — splash/player background base
  static const night1 = Color(0xFF171228);

  /// Mid-night — gradient midpoint
  static const night2 = Color(0xFF2A1B3D);

  /// Warm night edge — gradient top / richer violet
  static const night3 = Color(0xFF5B2E48);

  // ─── Warm accent palette ──────────────────────────────────────────────────
  /// Warm dusk rose — secondary warm accent
  static const dusk = Color(0xFF9C4A4A);

  /// Ember orange — warm accent fills, button glow
  static const ember = Color(0xFFE2885A);

  // ─── Light surfaces ("day" mode) ──────────────────────────────────────────
  /// Cream — primary day canvas / large surface
  static const cream = Color(0xFFFBF6EE);

  /// Paper — card and input surface, slightly cooler cream
  static const paper = Color(0xFFFFFDF9);

  // ─── Text ─────────────────────────────────────────────────────────────────
  /// Ink — primary body text and headings on light surfaces
  static const ink = Color(0xFF241F2E);

  /// Ink-2 — secondary / subdued text
  static const ink2 = Color(0xFF5C5566);

  /// Ink-3 — tertiary / placeholder / caption text
  static const ink3 = Color(0xFFA49CB2);

  // ─── CTA gradient endpoints ───────────────────────────────────────────────
  /// Accent — ember CTA gradient start (warm orange)
  static const accent = Color(0xFFE08A5B);

  /// Accent-2 — ember CTA gradient end (deep terracotta)
  static const accent2 = Color(0xFFC9685A);

  // ─── Highlight / "voice" moments ──────────────────────────────────────────
  /// Gold — follow-along word highlight, voice-moments accent
  static const gold = Color(0xFFE9B873);

  // ─── Home action tiles (warm, derived from the ember/gold family) ─────────
  /// "Make a Story" tile — warm gold (invites creation).
  static const tilePlay = gold;

  /// "Listen" tile — soft clay/peach, a warmer sibling of ember.
  static const tileListen = Color(0xFFE6A487);

  // ─── Borders & dividers ───────────────────────────────────────────────────
  /// Line — standard border / divider on light surfaces
  static const line = Color(0xFFEBE2D4);

  /// Line-2 — slightly stronger divider
  static const line2 = Color(0xFFDDD2C2);

  // ─── Semantic aliases (used in day ThemeData & existing screens) ──────────
  /// Primary day background (= cream)
  static const background = cream;

  /// Parent / admin screen background (= paper)
  static const backgroundParent = paper;

  /// Muted background for disabled / subtle fills
  static const backgroundMuted = Color(0xFFF3EEE7);

  /// Card and input surface (= paper)
  static const surface = paper;

  /// Primary text on light surface (= ink)
  static const textPrimary = ink;

  /// Deep brand ink — wordmark and brand elements (= night2)
  static const textDark = night2;

  /// Secondary text (= ink2)
  static const textSecondary = ink2;

  /// Muted text — slightly darker than secondary (= ink2)
  static const textMuted = ink2;

  /// Hint / placeholder text (= ink3)
  static const textHint = ink3;

  /// Disabled text / empty-dot color
  static const textDisabled = line2;

  // ─── Primary action (ember) ───────────────────────────────────────────────
  /// Primary action — ember (= accent)
  static const primary = accent;

  /// Darker primary for pressed / dark-surface treatment (= accent2)
  static const primaryDark = accent2;

  /// Strong primary for filled controls needing WCAG AA contrast (= accent2)
  static const primaryStrong = accent2;

  /// Deep primary for text/icon on pale surfaces (= dusk)
  static const primaryInk = dusk;

  /// Light primary tint
  static const primaryLight = Color(0xFFF0C09A);

  /// Primary shadow — ember glow at 40% opacity
  static const primaryShadow = Color(0x66E08A5B);

  // ─── Destructive ──────────────────────────────────────────────────────────
  /// Destructive action — warm red (unchanged from Shiru; no Storytime token)
  static const destructive = Color(0xFFFF6B6B);

  /// Accessible destructive foreground on pale surfaces
  static const destructiveDark = Color(0xFFB91C1C);

  /// Destructive shadow
  static const destructiveShadow = Color(0x40FF6B6B);

  // ─── Legacy accent aliases (Shiru purple → Storytime ember) ───────────────
  /// Legacy story-builder accent — mapped to ember for re-skin continuity
  static const accentDark = accent2;

  /// Legacy accent shadow — ember shadow
  static const accentShadow = Color(0x66E08A5B);

  // ─── Borders & surfaces (semantic) ────────────────────────────────────────
  /// Standard border (= line)
  static const border = line;

  /// Slightly stronger border (= line2)
  static const borderMuted = line2;

  // ─── Progress ─────────────────────────────────────────────────────────────
  /// Progress track background
  static const progressTrack = line;

  // ─── Legacy brand surface aliases ─────────────────────────────────────────
  /// Header icon backdrop — remapped to a warm cream tint
  static const logoSurface = Color(0xFFFAEDD8);

  /// Secondary brand accent — remapped to gold
  static const logoMint = gold;
}
