import 'package:flutter/material.dart';

class AppResponsive {
  AppResponsive._();

  /// Call once from a widget build method to get a scale factor.
  /// Base design width is 812px (typical landscape phone).
  static double scaleFactor(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    // Clamp between 0.85 (small phone) and 1.3 (large tablet)
    return (width / 812).clamp(0.85, 1.3);
  }

  /// Scaled font size
  static double fontSize(BuildContext context, double base) {
    return base * scaleFactor(context);
  }

  /// Scaled padding
  static double padding(BuildContext context, double base) {
    return base * scaleFactor(context);
  }

  /// Sprite scale factor (base is 6.0)
  static double spriteScale(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1000) return 8.0; // tablet
    if (width > 700) return 6.0;  // normal phone
    return 5.0;                    // small phone
  }

  /// Whether device is a tablet (width > 900px in landscape)
  static bool isTablet(BuildContext context) {
    return MediaQuery.of(context).size.width > 900;
  }
}
