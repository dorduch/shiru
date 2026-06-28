import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';

// ─── ThemeExtension ───────────────────────────────────────────────────────────

/// Custom Storytime design tokens that don't map onto Material [ColorScheme]
/// or [TextTheme] slots.  Retrieve at runtime via:
///
/// ```dart
/// final ext = Theme.of(context).extension<StorytimeTokens>()!;
/// ```
@immutable
class StorytimeTokens extends ThemeExtension<StorytimeTokens> {
  const StorytimeTokens({
    required this.night1,
    required this.night2,
    required this.night3,
    required this.ember,
    required this.dusk,
    required this.gold,
    required this.cream,
    required this.paper,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.accentColor,
    required this.accent2,
    required this.line,
    required this.line2,
    required this.eyebrow,
    required this.ctaGradient,
    required this.nightGradient,
    required this.onAccent,
    required this.trackInactive,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
  });

  // ─── Bedtime gradient stops ───────────────────────────────────────────────
  /// Deepest night — gradient base (#171228)
  final Color night1;

  /// Mid-night — gradient midpoint (#2A1B3D)
  final Color night2;

  /// Warm night edge (#5B2E48)
  final Color night3;

  // ─── Warm accents ─────────────────────────────────────────────────────────
  /// Ember orange — warm accent fills and button glow (#E2885A)
  final Color ember;

  /// Warm dusk rose (#9C4A4A)
  final Color dusk;

  /// Gold — follow-along word highlight / voice moments (#E9B873)
  final Color gold;

  // ─── Light surfaces ───────────────────────────────────────────────────────
  /// Cream — primary day canvas (#FBF6EE)
  final Color cream;

  /// Paper — card / input surface (#FFFDF9)
  final Color paper;

  // ─── Text ─────────────────────────────────────────────────────────────────
  /// Primary text on light surfaces (#241F2E)
  final Color ink;

  /// Secondary text (#5C5566)
  final Color ink2;

  /// Tertiary / placeholder text (#A49CB2)
  final Color ink3;

  // ─── CTA gradient ─────────────────────────────────────────────────────────
  /// Ember CTA gradient start (#E08A5B)
  final Color accentColor;

  /// Ember CTA gradient end / deep terracotta (#C9685A)
  final Color accent2;

  // ─── Borders / dividers ───────────────────────────────────────────────────
  /// Standard border on light surfaces (#EBE2D4)
  final Color line;

  /// Stronger divider (#DDD2C2)
  final Color line2;

  // ─── Special text style ───────────────────────────────────────────────────
  /// Eyebrow label style — Inter 600, 11px, wide tracking, uppercase.
  /// Apply `color: accent2` at call-site to match the spec.
  final TextStyle eyebrow;

  // ─── Gradient helpers ─────────────────────────────────────────────────────
  /// Ember CTA button gradient (accent → accent2, left-to-right)
  final LinearGradient ctaGradient;

  /// Night gradient for bedtime surfaces (night1 → night2 → night3, top-to-bottom)
  final LinearGradient nightGradient;

  // ─── Mode-aware semantic tokens ───────────────────────────────────────────
  // These differ between day and bedtime, so widgets must read them instead of
  // hardcoding Colors.white / ink / alpha literals. They are the seam that lets
  // a single widget render correctly on either surface (and makes a future
  // app-wide dark toggle a config change rather than a rewrite).

  /// Foreground (icon/label) on a filled accent control — e.g. the play button
  /// on its ember circle. A dark glyph (night1) clears 3:1 on ember/gold where
  /// white (2.66:1) fails.
  final Color onAccent;

  /// Inactive slider / progress track. Must stay visible against the surface so
  /// "remaining" progress is legible (visibility of system status).
  final Color trackInactive;

  /// Primary text/icon color for the current surface (ink on day, cream on night).
  final Color textPrimary;

  /// Secondary text for the current surface.
  final Color textSecondary;

  /// Tertiary / muted text for the current surface.
  final Color textTertiary;

  // ─── ThemeExtension boilerplate ───────────────────────────────────────────
  @override
  StorytimeTokens copyWith({
    Color? night1,
    Color? night2,
    Color? night3,
    Color? ember,
    Color? dusk,
    Color? gold,
    Color? cream,
    Color? paper,
    Color? ink,
    Color? ink2,
    Color? ink3,
    Color? accentColor,
    Color? accent2,
    Color? line,
    Color? line2,
    TextStyle? eyebrow,
    LinearGradient? ctaGradient,
    LinearGradient? nightGradient,
    Color? onAccent,
    Color? trackInactive,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
  }) {
    return StorytimeTokens(
      night1: night1 ?? this.night1,
      night2: night2 ?? this.night2,
      night3: night3 ?? this.night3,
      ember: ember ?? this.ember,
      dusk: dusk ?? this.dusk,
      gold: gold ?? this.gold,
      cream: cream ?? this.cream,
      paper: paper ?? this.paper,
      ink: ink ?? this.ink,
      ink2: ink2 ?? this.ink2,
      ink3: ink3 ?? this.ink3,
      accentColor: accentColor ?? this.accentColor,
      accent2: accent2 ?? this.accent2,
      line: line ?? this.line,
      line2: line2 ?? this.line2,
      eyebrow: eyebrow ?? this.eyebrow,
      ctaGradient: ctaGradient ?? this.ctaGradient,
      nightGradient: nightGradient ?? this.nightGradient,
      onAccent: onAccent ?? this.onAccent,
      trackInactive: trackInactive ?? this.trackInactive,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
    );
  }

  @override
  StorytimeTokens lerp(StorytimeTokens? other, double t) {
    if (other == null) return this;
    return StorytimeTokens(
      night1: Color.lerp(night1, other.night1, t)!,
      night2: Color.lerp(night2, other.night2, t)!,
      night3: Color.lerp(night3, other.night3, t)!,
      ember: Color.lerp(ember, other.ember, t)!,
      dusk: Color.lerp(dusk, other.dusk, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
      cream: Color.lerp(cream, other.cream, t)!,
      paper: Color.lerp(paper, other.paper, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      ink2: Color.lerp(ink2, other.ink2, t)!,
      ink3: Color.lerp(ink3, other.ink3, t)!,
      accentColor: Color.lerp(accentColor, other.accentColor, t)!,
      accent2: Color.lerp(accent2, other.accent2, t)!,
      line: Color.lerp(line, other.line, t)!,
      line2: Color.lerp(line2, other.line2, t)!,
      eyebrow: TextStyle.lerp(eyebrow, other.eyebrow, t)!,
      ctaGradient: LinearGradient.lerp(ctaGradient, other.ctaGradient, t)!,
      nightGradient:
          LinearGradient.lerp(nightGradient, other.nightGradient, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      trackInactive: Color.lerp(trackInactive, other.trackInactive, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
    );
  }
}

// ─── Shared extension instance ────────────────────────────────────────────────

/// The canonical [StorytimeTokens] values — identical for both day and
/// bedtime themes (the modes differ only in how ColorScheme maps them, not
/// in the token values themselves).
const _tokens = StorytimeTokens(
  night1: AppColors.night1,
  night2: AppColors.night2,
  night3: AppColors.night3,
  ember: AppColors.ember,
  dusk: AppColors.dusk,
  gold: AppColors.gold,
  cream: AppColors.cream,
  paper: AppColors.paper,
  ink: AppColors.ink,
  ink2: AppColors.ink2,
  ink3: AppColors.ink3,
  accentColor: AppColors.accent,
  accent2: AppColors.accent2,
  line: AppColors.line,
  line2: AppColors.line2,
  // eyebrow and gradients are runtime, so StorytimeTheme.day/bedtime set them
  // below via a non-const override; _tokens is used as the const base only for
  // the colors/lines fields. The ThemeData extensions list uses the full
  // instances defined in StorytimeTheme.
  eyebrow: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.9),
  ctaGradient: LinearGradient(
    colors: [AppColors.accent, AppColors.accent2],
  ),
  nightGradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.night3, AppColors.night2, AppColors.night1],
  ),
  // Day defaults for the mode-aware semantic tokens. Bedtime overrides the
  // surface-dependent ones in [_bedtimeTokens] below.
  onAccent: AppColors.night1,
  trackInactive: AppColors.line,
  textPrimary: AppColors.ink,
  textSecondary: AppColors.ink2,
  textTertiary: AppColors.ink3,
);

/// Bedtime variant: same brand colors, but the surface-dependent semantic
/// tokens flip to read correctly on the night gradient. (Not const because the
/// cream-alpha values are computed.)
final _bedtimeTokens = _tokens.copyWith(
  trackInactive: AppColors.cream.withValues(alpha: 0.35),
  textPrimary: AppColors.cream,
  textSecondary: AppColors.cream.withValues(alpha: 0.7),
  textTertiary: AppColors.cream.withValues(alpha: 0.5),
);

// ─── StorytimeTheme ───────────────────────────────────────────────────────────

/// Factory for the two Storytime [ThemeData] objects.
///
/// Usage in [MaterialApp]:
/// ```dart
/// MaterialApp.router(
///   theme: StorytimeTheme.day,
///   darkTheme: StorytimeTheme.bedtime,
///   themeMode: ThemeMode.light, // pin to day unless explicitly toggled
///   ...
/// )
/// ```
///
/// Custom tokens in widgets:
/// ```dart
/// final tokens = Theme.of(context).extension<StorytimeTokens>()!;
/// ```
abstract final class StorytimeTheme {
  // ─── Shared text theme ──────────────────────────────────────────────────
  // Every one of the 13 TextTheme slots is populated so Material never falls
  // back to its default (SF/Roboto) for a slot we left unset — display/headline/
  // title-large use Fraunces, the rest Inter.
  static TextTheme get _textTheme => TextTheme(
        displayLarge: AppTypography.displayLarge,
        displayMedium: AppTypography.displayMedium,
        displaySmall: AppTypography.headlineMedium,
        headlineLarge: AppTypography.displayMedium,
        headlineMedium: AppTypography.headlineMedium,
        headlineSmall: AppTypography.headlineSmall,
        titleLarge: AppTypography.titleLarge,
        titleMedium: AppTypography.titleMedium,
        titleSmall: AppTypography.labelLarge,
        bodyLarge: AppTypography.bodyLarge,
        bodyMedium: AppTypography.bodyMedium,
        bodySmall: AppTypography.bodySmall,
        labelLarge: AppTypography.labelLarge,
        labelMedium: AppTypography.labelMedium,
        labelSmall: AppTypography.labelSmall,
      );

  // ─── Day (light) theme ───────────────────────────────────────────────────
  /// Light / "day" theme — cream surfaces, ink text, ember primary.
  static ThemeData get day {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.accent,
      onPrimary: AppColors.paper,
      secondary: AppColors.accent2,
      onSecondary: AppColors.paper,
      error: AppColors.destructive,
      onError: AppColors.paper,
      surface: AppColors.paper,
      onSurface: AppColors.ink,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.cream,
      // Use the per-slot theme directly: each AppTypography slot already picks
      // Nunito (display/headline/title) or Inter (body/label). Wrapping it in
      // GoogleFonts.interTextTheme() would re-apply Inter to every slot and
      // silently strip Nunito from theme-driven text (e.g. AppBar titles).
      textTheme: _textTheme,
      extensions: const [_tokens],
    );
  }

  // ─── Bedtime (dark) theme ─────────────────────────────────────────────────
  /// Dark / "bedtime" theme — night-gradient background, cream text, gold accent.
  static ThemeData get bedtime {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.gold,
      onPrimary: AppColors.night1,
      secondary: AppColors.ember,
      onSecondary: AppColors.night1,
      error: AppColors.destructive,
      onError: AppColors.night1,
      surface: AppColors.night2,
      onSurface: AppColors.cream,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.night1,
      // Per-slot fonts preserved (see day theme note); only recolor for dark.
      textTheme: _textTheme.apply(
        bodyColor: AppColors.cream,
        displayColor: AppColors.cream,
      ),
      extensions: [_bedtimeTokens],
    );
  }
}
