import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ─── Backgrounds ─────────────────────────────────────────────────────────
  /// Warm parchment — primary Shiru canvas
  static const background = Color(0xFFF4F1EC);

  /// Cool gray — parent screens & pin screen
  static const backgroundParent = Color(0xFFF6F7F8);

  /// Slightly lighter gray — muted buttons (DEL key, stop button)
  static const backgroundMuted = Color(0xFFF3F4F6);

  /// Pure white — cards, inputs, surface containers
  static const surface = Colors.white;

  // ─── Text ─────────────────────────────────────────────────────────────────
  /// Near-black — card titles, primary body text, keypad numbers
  static const textPrimary = Color(0xFF1A1A1A);

  /// Deep navy — Shiru wordmark and brand ink
  static const textDark = Color(0xFF243B67);

  /// Medium gray — subtitles, button labels, empty-state text hint
  static const textSecondary = Color(0xFF6B7280);

  /// Slightly darker gray — voice section labels, back button icon
  static const textMuted = Color(0xFF374151);

  /// Light gray — placeholder / hint text
  static const textHint = Color(0xFF9CA3AF);

  /// Very light gray — PIN empty dots, disabled states
  static const textDisabled = Color(0xFFD1D5DB);

  // ─── Brand / Actions ──────────────────────────────────────────────────────
  /// Green — primary action (save, active tab, "Now Playing")
  static const primary = Color(0xFF22C55E);
  static const primaryDark = Color(0xFF16A34A);
  static const primaryLight = Color(0xFF4ADE80);
  static const primaryShadow = Color(0x4022C55E);

  /// Red — destructive actions only (delete, error borders, playing card glow)
  static const destructive = Color(0xFFFF6B6B);
  static const destructiveShadow = Color(0x40FF6B6B);

  /// Purple — story builder accent
  static const accent = Color(0xFF8B5CF6);
  static const accentDark = Color(0xFF6D28D9);
  static const accentShadow = Color(0x408B5CF6);

  // ─── Borders & Dividers ───────────────────────────────────────────────────
  /// Standard input / container border
  static const border = Color(0xFFE5E7EB);

  /// Slightly darker border — outlined secondary buttons, PIN empty dots
  static const borderMuted = Color(0xFFD1D5DB);

  // ─── Misc ─────────────────────────────────────────────────────────────────
  /// Progress bar track background, inactive step dots
  static const progressTrack = Color(0xFFE5E7EB);

  // ─── Brand ───────────────────────────────────────────────────────────────
  /// Soft sky — header icon backdrop
  static const logoSurface = Color(0xFFD8E9FF);

  /// Mint highlight — secondary Shiru brand accent
  static const logoMint = Color(0xFFBFF7E8);
}
