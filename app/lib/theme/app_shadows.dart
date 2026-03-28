import 'package:flutter/material.dart';

class AppShadows {
  AppShadows._();

  /// Standard card/button shadow — used on list rows, keypad keys, small containers
  static const card = [
    BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 4)),
  ];

  /// Elevated shadow — used on card grid tiles, player pill, preview card
  static const elevated = [
    BoxShadow(color: Colors.black12, blurRadius: 24, offset: Offset(0, 12)),
  ];

  /// Subtle shadow — tabs, small floating buttons (blur 8)
  static const subtle = [
    BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
  ];

  /// Green glow — primary/save action buttons
  static const primaryGlow = [
    BoxShadow(color: Color(0x4022C55E), blurRadius: 16, offset: Offset(0, 8)),
  ];

  /// Red glow — destructive/play action buttons
  static const destructiveGlow = [
    BoxShadow(color: Color(0x40FF6B6B), blurRadius: 12, offset: Offset(0, 4)),
  ];

  /// Purple glow — story builder accent buttons
  static const accentGlow = [
    BoxShadow(color: Color(0x408B5CF6), blurRadius: 12, offset: Offset(0, 4)),
  ];
}
