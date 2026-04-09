import 'package:flutter/material.dart';

enum SizeClass { xs, sm, md, lg }

class AppResponsive {
  AppResponsive._();

  static SizeClass sizeClass(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 480) return SizeClass.xs;
    if (width < 720) return SizeClass.sm;
    if (width < 1024) return SizeClass.md;
    return SizeClass.lg;
  }

  static double scaleFactor(BuildContext context) =>
      switch (sizeClass(context)) {
        SizeClass.xs => 0.80,
        SizeClass.sm => 0.90,
        SizeClass.md => 1.00,
        SizeClass.lg => 1.20,
      };

  static double spacing(BuildContext context, double base) =>
      base * scaleFactor(context);

  static double fontSize(BuildContext context, double base) =>
      base * scaleFactor(context);

  static double iconSize(BuildContext context, double base) =>
      base * scaleFactor(context);

  static double buttonSize(BuildContext context) =>
      switch (sizeClass(context)) {
        SizeClass.xs => 44.0,
        SizeClass.sm => 48.0,
        SizeClass.md => 56.0,
        SizeClass.lg => 64.0,
      };

  static double spriteScale(BuildContext context) =>
      switch (sizeClass(context)) {
        SizeClass.xs => 4.0,
        SizeClass.sm => 5.0,
        SizeClass.md => 6.0,
        SizeClass.lg => 8.0,
      };

  static double gridMaxExtent(BuildContext context) =>
      switch (sizeClass(context)) {
        SizeClass.xs => 160.0,
        SizeClass.sm => 200.0,
        SizeClass.md => 240.0,
        SizeClass.lg => 300.0,
      };

  static double basePadding(BuildContext context) =>
      switch (sizeClass(context)) {
        SizeClass.xs => 12.0,
        SizeClass.sm => 16.0,
        SizeClass.md => 20.0,
        SizeClass.lg => 28.0,
      };

  static bool isCompact(BuildContext context) {
    final currentSizeClass = sizeClass(context);
    return currentSizeClass == SizeClass.xs || currentSizeClass == SizeClass.sm;
  }

  static bool isPortrait(BuildContext context) =>
      MediaQuery.of(context).orientation == Orientation.portrait;

  static bool isTablet(BuildContext context) => !isCompact(context);
}
