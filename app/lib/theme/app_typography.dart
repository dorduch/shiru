import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Storytime typography scale.
///
/// Two typefaces:
///   • **Nunito** (rounded sans) — display, headlines, titles, wordmark and the
///     story "read" text.  Soft, friendly and modern; heavy weights (700/800)
///     carry the headings, 500 for long-form reading.
///   • **Inter** (sans-serif) — body copy, labels, UI controls.
///     Weights 400 / 500 / 600.
///
/// All fields are `static final` (GoogleFonts returns runtime TextStyle
/// instances, so const is not possible).  Callers may continue to call
/// `.copyWith(...)` exactly as before.
class AppTypography {
  AppTypography._();

  // ─── Display ──────────────────────────────────────────────────────────────
  /// Screen headings: "Library", "New Card", "Edit Card" (Nunito 32 w800)
  static final displayLarge = GoogleFonts.nunito(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.2,
    height: 1.1,
  );

  /// Sub-display: "Parents Only!" (Nunito 28 w800)
  static final displayMedium = GoogleFonts.nunito(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.2,
    height: 1.1,
  );

  // ─── Headlines ────────────────────────────────────────────────────────────
  /// Section titles, list card text (Nunito 24 w700)
  static final headlineMedium = GoogleFonts.nunito(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.1,
    height: 1.15,
  );

  /// Story builder header title (Nunito 22 w700)
  static final headlineSmall = GoogleFonts.nunito(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.1,
    height: 1.15,
  );

  // ─── Titles ───────────────────────────────────────────────────────────────
  /// Card title in grid / player pill / preview (Nunito 20 w700)
  static final titleLarge = GoogleFonts.nunito(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
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
  /// App wordmark (Nunito 30 w800)
  static final logoWordmark = GoogleFonts.nunito(
    fontSize: 30,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.5,
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

  /// Story "read" text — Nunito 500 at 17px with generous line-height
  static final storyBody = GoogleFonts.nunito(
    fontSize: 17,
    fontWeight: FontWeight.w500,
    height: 1.85,
  );

  /// Eyebrow label — Inter 700, 12.5px, wide tracking, uppercase. Color applied
  /// by callers via `.copyWith(color: AppColors.eyebrow)`. Bumped from 11/w600
  /// so small all-caps text stays legible (see AppColors.eyebrow for contrast).
  static final eyebrow = GoogleFonts.inter(
    fontSize: 12.5,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.6,
  );
}
