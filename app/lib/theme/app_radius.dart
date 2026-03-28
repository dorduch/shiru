import 'package:flutter/material.dart';

class AppRadius {
  AppRadius._();

  /// 8px — sprite thumbnail containers, small chips
  static final small = BorderRadius.circular(8);

  /// 16px — input fields, inner card art containers, dropdown wrappers
  static final medium = BorderRadius.circular(16);

  /// 24px — main card tiles, primary action buttons, list items
  static final large = BorderRadius.circular(24);

  /// 999px — pills: category tabs, player pill, circular icon buttons
  static final full = BorderRadius.circular(999);
}
