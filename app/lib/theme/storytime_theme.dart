import 'package:flutter/material.dart';

class StorytimeColors {
  StorytimeColors._();

  static const background = Color(0xFFF7F3EC);
  static const surface = Color(0xFFFFFDFC);
  static const ink = Color(0xFF292638);
  static const muted = Color(0xFF716D7E);
  static const accent = Color(0xFF6657D9);
  static const accentSoft = Color(0xFFEAE7FF);
  static const yellow = Color(0xFFFFD66B);
  static const mint = Color(0xFF7FD1C4);
  static const coral = Color(0xFFFF9B8A);
  static const lilac = Color(0xFFB59BFF);
  static const border = Color(0xFFE1DCE8);
  static const danger = Color(0xFFB4233D);
}

ThemeData storytimeTheme() => ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: StorytimeColors.background,
  colorScheme: ColorScheme.fromSeed(
    seedColor: StorytimeColors.accent,
    surface: StorytimeColors.surface,
  ),
  textTheme: const TextTheme(
    headlineLarge: TextStyle(
      fontSize: 34,
      fontWeight: FontWeight.w800,
      color: StorytimeColors.ink,
    ),
    headlineMedium: TextStyle(
      fontSize: 26,
      fontWeight: FontWeight.w800,
      color: StorytimeColors.ink,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: StorytimeColors.ink,
    ),
    bodyLarge: TextStyle(fontSize: 17, color: StorytimeColors.ink),
    bodyMedium: TextStyle(fontSize: 15, color: StorytimeColors.muted),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(64, 56),
      backgroundColor: StorytimeColors.accent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: StorytimeColors.surface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: StorytimeColors.border),
    ),
  ),
);
