import 'package:flutter/material.dart';
import 'package:submersion/core/theme/feature_accent_colors.dart';

// ---------------------------------------------------------------------------
// Minimalist Theme -- clean, near-monochrome
// Thin borders, light font weights, system font only.
// ---------------------------------------------------------------------------

// -- Colors ------------------------------------------------------------------

const _surfaceLight = Color(0xFFFAFAFA);
const _surfaceDark = Color(0xFF121212);

const _primaryLight = Color(0xFF475569);
const _primaryDark = Color(0xFF94A3B8);

const _cardLight = Color(0xFFFFFFFF);
const _cardDark = Color(0xFF1E1E1E);

const _cardBorderLight = Color(0xFFE8E8E8);
const _cardBorderDark = Color(0xFF333333);

const _fabLight = Color(0xFF333333);
const _fabDark = Color(0xFFE0E0E0);

const _errorColor = Color(0xFFB00020);
const _onErrorColor = Color(0xFFFFFFFF);

// -- Shared shape constants --------------------------------------------------

const _cardRadius = 8.0;
const _fabRadius = 8.0;
const _inputRadius = 6.0;

// -- Text themes -------------------------------------------------------------

TextTheme _buildTextTheme(Brightness brightness) {
  final base = brightness == Brightness.light
      ? ThemeData.light().textTheme
      : ThemeData.dark().textTheme;

  return base.copyWith(
    displayLarge: base.displayLarge?.copyWith(fontWeight: FontWeight.w500),
    displayMedium: base.displayMedium?.copyWith(fontWeight: FontWeight.w500),
    displaySmall: base.displaySmall?.copyWith(fontWeight: FontWeight.w500),
    headlineLarge: base.headlineLarge?.copyWith(fontWeight: FontWeight.w500),
    headlineMedium: base.headlineMedium?.copyWith(fontWeight: FontWeight.w500),
    headlineSmall: base.headlineSmall?.copyWith(fontWeight: FontWeight.w500),
    titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w500),
    titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w500),
    titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w500),
    bodyLarge: base.bodyLarge?.copyWith(fontWeight: FontWeight.w300),
    bodyMedium: base.bodyMedium?.copyWith(fontWeight: FontWeight.w300),
    bodySmall: base.bodySmall?.copyWith(fontWeight: FontWeight.w300),
    labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w300),
    labelMedium: base.labelMedium?.copyWith(fontWeight: FontWeight.w300),
    labelSmall: base.labelSmall?.copyWith(fontWeight: FontWeight.w300),
  );
}

// -- Light -------------------------------------------------------------------

final ThemeData minimalistLight = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  extensions: const <ThemeExtension<dynamic>>[FeatureAccentColors.light],
  colorScheme: const ColorScheme(
    brightness: Brightness.light,
    primary: _primaryLight,
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFF64748B),
    onSecondary: Color(0xFFFFFFFF),
    error: _errorColor,
    onError: _onErrorColor,
    surface: _surfaceLight,
    onSurface: Color(0xFF1E1E1E),
    surfaceContainerLow: _cardLight,
  ),
  textTheme: _buildTextTheme(Brightness.light),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: Color(0xFF1E1E1E),
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
  ),
  cardTheme: CardThemeData(
    color: _cardLight,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_cardRadius),
      side: const BorderSide(color: _cardBorderLight),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_inputRadius),
    ),
  ),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: _fabLight,
    foregroundColor: const Color(0xFFFFFFFF),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_fabRadius),
    ),
  ),
);

// -- Dark --------------------------------------------------------------------

final ThemeData minimalistDark = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  extensions: const <ThemeExtension<dynamic>>[FeatureAccentColors.dark],
  colorScheme: const ColorScheme(
    brightness: Brightness.dark,
    primary: _primaryDark,
    onPrimary: Color(0xFF1E1E1E),
    secondary: Color(0xFF64748B),
    onSecondary: Color(0xFFFFFFFF),
    error: _errorColor,
    onError: _onErrorColor,
    surface: _surfaceDark,
    onSurface: Color(0xFFE0E0E0),
    surfaceContainerLow: _cardDark,
  ),
  textTheme: _buildTextTheme(Brightness.dark),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: Color(0xFFE0E0E0),
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
  ),
  cardTheme: CardThemeData(
    color: _cardDark,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_cardRadius),
      side: const BorderSide(color: _cardBorderDark),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_inputRadius),
    ),
  ),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: _fabDark,
    foregroundColor: const Color(0xFF1E1E1E),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_fabRadius),
    ),
  ),
);
