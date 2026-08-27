import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:submersion/core/theme/feature_accent_colors.dart';

// ---------------------------------------------------------------------------
// Console Theme -- instrument-panel aesthetic
// Sharp corners, monospace accents, bordered cards, zero elevation.
// ---------------------------------------------------------------------------

// -- Colors ------------------------------------------------------------------

const _surfaceLight = Color(0xFFF0F2F5);
const _surfaceDark = Color(0xFF141A22);

const _appBarLight = Color(0xFF2A3444);
const _appBarDark = Color(0xFF1A2230);

const _primaryLight = Color(0xFF1A2230);
const _primaryDark = Color(0xFF4AE0C0);

const _onPrimaryLight = Color(0xFFFFFFFF);
const _onPrimaryDark = Color(0xFF0A1018);

const _cardLight = Color(0xFFFFFFFF);
const _cardDark = Color(0xFF1A2230);

const _cardBorderLight = Color(0xFFD0D8E0);
const _cardBorderDark = Color(0xFF2A3A4A);

const _fabLight = Color(0xFF1A2230);
const _fabDark = Color(0xFF4AE0C0);

const _errorColor = Color(0xFFB00020);
const _onErrorColor = Color(0xFFFFFFFF);

// -- Shared shape constants --------------------------------------------------

const _cardRadius = 4.0;
const _fabRadius = 4.0;
const _inputRadius = 4.0;

// -- Text themes -------------------------------------------------------------

/// Builds a text theme with JetBrains Mono for headlines/titles (via
/// google_fonts) and the default system font for body/label text.
TextTheme _buildTextTheme(Brightness brightness) {
  final base = brightness == Brightness.light
      ? ThemeData.light().textTheme
      : ThemeData.dark().textTheme;

  final mono = GoogleFonts.jetBrainsMonoTextTheme(base);

  return mono.copyWith(
    bodyLarge: base.bodyLarge,
    bodyMedium: base.bodyMedium,
    bodySmall: base.bodySmall,
    labelLarge: base.labelLarge,
    labelMedium: base.labelMedium,
    labelSmall: base.labelSmall,
  );
}

// -- Light -------------------------------------------------------------------

final ThemeData consoleLight = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  extensions: const <ThemeExtension<dynamic>>[FeatureAccentColors.light],
  colorScheme: const ColorScheme(
    brightness: Brightness.light,
    primary: _primaryLight,
    onPrimary: _onPrimaryLight,
    secondary: _appBarLight,
    onSecondary: _onPrimaryLight,
    error: _errorColor,
    onError: _onErrorColor,
    surface: _surfaceLight,
    onSurface: _primaryLight,
    surfaceContainerLow: _cardLight,
  ),
  textTheme: _buildTextTheme(Brightness.light),
  appBarTheme: const AppBarTheme(
    backgroundColor: _appBarLight,
    foregroundColor: _onPrimaryLight,
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
    foregroundColor: _onPrimaryLight,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_fabRadius),
    ),
  ),
);

// -- Dark --------------------------------------------------------------------

final ThemeData consoleDark = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  extensions: const <ThemeExtension<dynamic>>[FeatureAccentColors.dark],
  colorScheme: const ColorScheme(
    brightness: Brightness.dark,
    primary: _primaryDark,
    onPrimary: _onPrimaryDark,
    secondary: _appBarDark,
    onSecondary: _onPrimaryLight,
    error: _errorColor,
    onError: _onErrorColor,
    surface: _surfaceDark,
    onSurface: Color(0xFFE0E4E8),
    surfaceContainerLow: _cardDark,
  ),
  textTheme: _buildTextTheme(Brightness.dark),
  appBarTheme: const AppBarTheme(
    backgroundColor: _appBarDark,
    foregroundColor: _primaryDark,
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
    foregroundColor: _onPrimaryDark,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_fabRadius),
    ),
  ),
);
