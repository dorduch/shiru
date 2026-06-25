import 'package:flutter/material.dart';

/// Storytime shadow tokens.
///
/// Warm soft shadows replace the legacy neutral black-12 system.
/// Two primary shadow personalities:
///   • **ember glow** — for CTA buttons (accent/accent-2 palette)
///   • **bedtime depth** — for dark overlaid surfaces (player, splash)
///
/// Legacy field names are preserved so that existing callers compile without
/// modification.
class AppShadows {
  AppShadows._();

  /// Standard card shadow — warm, soft, used on list rows and small containers
  static const card = [
    BoxShadow(
      color: Color(0x1A241F2E), // ink at ~10%
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  /// Elevated shadow — card grid tiles, player pill, preview card
  static const elevated = [
    BoxShadow(
      color: Color(0x26241F2E), // ink at ~15%
      blurRadius: 24,
      offset: Offset(0, 12),
    ),
  ];

  /// Subtle shadow — tabs, small floating buttons
  static const subtle = [
    BoxShadow(
      color: Color(0x14241F2E), // ink at ~8%
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  /// Ember CTA glow — primary / save action buttons
  /// `0 10px 24px rgba(201,104,90,.30)` — accent-2 at 30%
  static const primaryGlow = [
    BoxShadow(
      color: Color(0x4DC9685A), // accent-2 at 30%
      blurRadius: 24,
      offset: Offset(0, 10),
    ),
  ];

  /// Bedtime depth shadow — dark overlaid surfaces, device mockup depth
  /// `0 40px 100px rgba(0,0,0,.50)`
  static const bedtimeDepth = [
    BoxShadow(
      color: Color(0x80000000), // black at 50%
      blurRadius: 100,
      offset: Offset(0, 40),
    ),
  ];

  /// Destructive / delete action shadow (unchanged from Shiru)
  static const destructiveGlow = [
    BoxShadow(
      color: Color(0x40FF6B6B),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  // ─── Legacy aliases ───────────────────────────────────────────────────────
  /// Legacy name for primaryGlow — kept for backward compatibility
  static const accentGlow = primaryGlow;
}
