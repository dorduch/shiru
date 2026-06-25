import 'package:flutter/material.dart';

/// Storytime radius scale.
///
/// Derived from the wireframe mockups (§4.3 of the MVP plan).  All values
/// are `final` (BorderRadius.circular is not const in Flutter).
class AppRadius {
  AppRadius._();

  /// 14px — input fields, inner card art containers, small chips
  static final small = BorderRadius.circular(14);

  /// 16px — dropdown wrappers, secondary containers
  static final medium = BorderRadius.circular(16);

  /// 20px — main card tiles, primary action buttons, list items
  static final large = BorderRadius.circular(20);

  /// 36px — bottom sheets, full-screen surface containers
  static final sheet = BorderRadius.circular(36);

  /// 999px — pills: category tabs, player pill, circular icon buttons
  static final full = BorderRadius.circular(999);
}
