import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Storytime typography scale.
///
/// Two typefaces:
///   • **Fraunces** (serif) — display, headlines, titles and story "read" text.
///     Tight tracking (≈ -0.01 em), line-height 1.1 for headings, 1.85 for
///     read text.  Weights 400 / 500 / 600.
///   • **Inter** (sans-serif) — body copy, labels, UI controls.
///     Weights 400 / 500 / 600.
///
/// All fields are `static final` (GoogleFonts returns runtime TextStyle
/// instances, so const is not possible).  Callers may continue to call
/// `.copyWith(...)` exactly as before.
class AppTypography {
  AppTypography._();

  // ─── Display ──────────────────────────────────────────────────────────────
  /// Screen headings: "Library", "New Card", "Edit Card" (Fraunces 32 w600)
  static final displayLarge = GoogleFonts.fraunces(
    fontSize: 32,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    height: 1.1,
  );

  /// Sub-display: "Parents Only!" (Fraunces 28 w600)
  static final displayMedium = GoogleFonts.fraunces(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
    height: 1.1,
  );

  // ─── Headlines ────────────────────────────────────────────────────────────
  /// Section titles, list card text (Fraunces 24 w500)
  static final headlineMedium = GoogleFonts.fraunces(
    fontSize: 24,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.3,
    height: 1.1,
  );

  /// Story builder header title (Fraunces 22 w600)
  static final headlineSmall = GoogleFonts.fraunces(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    height: 1.1,
  );

  // ─── Titles ───────────────────────────────────────────────────────────────
  /// Card title in grid / player pill / preview (Fraunces 20 w500)
  static final titleLarge = GoogleFonts.fraunces(
    fontSize: 20,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.2,
    height: 1.2,
  );

  /// Section labels and sub-headers (Inter 18 w600)
  static final titleMedium = GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );

  // ─── Body ─────────────────────────────────────────────────────────────────
  /// Primary button labels, category tabs, "Story Builder" link (Inter 16 w600)
  static final bodyLarge = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  /// Secondary button labels, field labels (Inter 16 w500)
  static final bodyMedium = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );

  /// Input text, dropdown text, general body copy (Inter 16 w400)
  static final bodySmall = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
  );

  // ─── Labels ───────────────────────────────────────────────────────────────
  /// Player pill status, progress percentage (Inter 14 w600)
  static final labelLarge = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  /// Body copy, secondary descriptions (Inter 14 w400)
  static final labelMedium = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
  );

  /// Small captions (Inter 12 w400)
  static final labelSmall = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );

  // ─── Special ─────────────────────────────────────────────────────────────
  /// App wordmark (Fraunces 30 w400)
  static final logoWordmark = GoogleFonts.fraunces(
    fontSize: 30,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );

  /// Keypad digit buttons (Inter 28 w700)
  static final keypadDigit = GoogleFonts.inter(
    fontSize: 28,
    fontWeight: FontWeight.w700,
  );

  /// Input field text (Inter 18 w500)
  static final inputText = GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w500,
  );

  /// Story "read" text — Fraunces 400 at 17px with generous line-height
  static final storyBody = GoogleFonts.fraunces(
    fontSize: 17,
    fontWeight: FontWeight.w400,
    height: 1.85,
  );

  /// Eyebrow label — Inter 600, 11px, wide tracking, uppercase, accent-2 color
  /// applied by callers via `.copyWith(color: AppColors.accent2)`.
  static final eyebrow = GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.9,
  );
}
