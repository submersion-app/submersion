import 'package:flutter/material.dart';
import 'package:submersion/core/theme/feature_accent_colors.dart';

// ---------------------------------------------------------------------------
// Submersion Theme -- the default ocean-blue Material 3 theme
// Uses ColorScheme.fromSeed for automatic palette generation with shared
// component overrides for consistent card, input, and FAB styling.
// ---------------------------------------------------------------------------

const _seedColor = Color(0xFF0077B6);

final ThemeData submersionLight = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  extensions: const <ThemeExtension<dynamic>>[FeatureAccentColors.light],
  colorScheme: ColorScheme.fromSeed(
    seedColor: _seedColor,
    brightness: Brightness.light,
  ),
  appBarTheme: const AppBarTheme(
    centerTitle: false,
    elevation: 0,
    scrolledUnderElevation: 0,
  ),
  cardTheme: CardThemeData(
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
  ),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),
);

final ThemeData submersionDark = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  extensions: const <ThemeExtension<dynamic>>[FeatureAccentColors.dark],
  colorScheme: ColorScheme.fromSeed(
    seedColor: _seedColor,
    brightness: Brightness.dark,
  ),
  appBarTheme: const AppBarTheme(
    centerTitle: false,
    elevation: 0,
    scrolledUnderElevation: 0,
  ),
  cardTheme: CardThemeData(
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
  ),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),
);
