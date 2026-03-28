import 'package:flutter/material.dart';

class AppTypography {
  AppTypography._();

  // ─── Display ──────────────────────────────────────────────────────────────
  /// Screen headings: "Library", "New Card", "Edit Card" (32 w800)
  static const displayLarge = TextStyle(fontSize: 32, fontWeight: FontWeight.w800);

  /// Sub-display: "Parents Only!" (28 w800)
  static const displayMedium = TextStyle(fontSize: 28, fontWeight: FontWeight.w800);

  // ─── Headlines ────────────────────────────────────────────────────────────
  /// Section titles, list card text: "Library" list items (24 w700)
  static const headlineMedium = TextStyle(fontSize: 24, fontWeight: FontWeight.w700);

  /// Story builder header title (22 w800)
  static const headlineSmall = TextStyle(fontSize: 22, fontWeight: FontWeight.w800);

  // ─── Titles ───────────────────────────────────────────────────────────────
  /// Card title in grid / player pill / preview (20 w800)
  static const titleLarge = TextStyle(fontSize: 20, fontWeight: FontWeight.w800);

  /// Section labels and sub-headers: "Preview", voice sections (18 w600)
  static const titleMedium = TextStyle(fontSize: 18, fontWeight: FontWeight.w600);

  // ─── Body ─────────────────────────────────────────────────────────────────
  /// Primary button labels, category tab text, "Story Builder" link (16 w700)
  static const bodyLarge = TextStyle(fontSize: 16, fontWeight: FontWeight.w700);

  /// Secondary button labels, field labels ("Title", "Audio") (16 w600 / bold)
  static const bodyMedium = TextStyle(fontSize: 16, fontWeight: FontWeight.w600);

  /// Input text, dropdown text (16 w400)
  static const bodySmall = TextStyle(fontSize: 16, fontWeight: FontWeight.w400);

  // ─── Labels ───────────────────────────────────────────────────────────────
  /// Player pill status, progress percentage (14 w600)
  static const labelLarge = TextStyle(fontSize: 14, fontWeight: FontWeight.w600);

  /// Body copy, secondary descriptions (14 w400)
  static const labelMedium = TextStyle(fontSize: 14, fontWeight: FontWeight.w400);

  /// Small captions (12 w400)
  static const labelSmall = TextStyle(fontSize: 12, fontWeight: FontWeight.w400);

  // ─── Special ─────────────────────────────────────────────────────────────
  /// App logo "Shiru" wordmark (28 w900)
  static const logoWordmark = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w900,
    letterSpacing: 1.2,
  );

  /// Keypad digit buttons (28 bold)
  static const keypadDigit = TextStyle(fontSize: 28, fontWeight: FontWeight.bold);

  /// Input field text (18 w500)
  static const inputText = TextStyle(fontSize: 18, fontWeight: FontWeight.w500);
}
