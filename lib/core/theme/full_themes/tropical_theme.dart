import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:submersion/core/theme/feature_accent_colors.dart';

// ---------------------------------------------------------------------------
// Tropical Theme -- bubbly, warm, coral-accented
// Rounded everything, elevated cards, playful palette.
// ---------------------------------------------------------------------------

// -- Colors ------------------------------------------------------------------

const _surfaceLight = Color(0xFFF0FAF8);
const _surfaceDark = Color(0xFF101A18);

const _appBarLight = Color(0xFF00B4A0);
const _appBarDark = Color(0xFF152824);

const _primaryLight = Color(0xFF00B4A0);
const _primaryDark = Color(0xFF40D0BE);

const _secondaryLight = Color(0xFFE07A5F);
const _secondaryDark = Color(0xFFE8957E);

const _cardLight = Color(0xFFFFFFFF);
const _cardDark = Color(0xFF1A2A26);

const _fabColor = Color(0xFFE07A5F);

const _errorColor = Color(0xFFB00020);
const _onErrorColor = Color(0xFFFFFFFF);

// -- Shared shape constants --------------------------------------------------

const _cardRadius = 20.0;
const _fabRadius = 22.0;
const _inputRadius = 16.0;

// -- Text themes -------------------------------------------------------------

/// Builds a text theme using Nunito for all text via google_fonts.
TextTheme _buildTextTheme(Brightness brightness) {
  final base = brightness == Brightness.light
      ? ThemeData.light().textTheme
      : ThemeData.dark().textTheme;

  return GoogleFonts.nunitoTextTheme(base);
}

// -- Light -------------------------------------------------------------------

final ThemeData tropicalLight = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  extensions: const <ThemeExtension<dynamic>>[FeatureAccentColors.light],
  colorScheme: const ColorScheme(
    brightness: Brightness.light,
    primary: _primaryLight,
    onPrimary: Color(0xFFFFFFFF),
    secondary: _secondaryLight,
    onSecondary: Color(0xFFFFFFFF),
    error: _errorColor,
    onError: _onErrorColor,
    surface: _surfaceLight,
    onSurface: Color(0xFF1A2A26),
    surfaceContainerLow: _cardLight,
  ),
  textTheme: _buildTextTheme(Brightness.light),
  appBarTheme: const AppBarTheme(
    backgroundColor: _appBarLight,
    foregroundColor: Color(0xFFFFFFFF),
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
  ),
  cardTheme: CardThemeData(
    color: _cardLight,
    elevation: 4,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_cardRadius),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_inputRadius),
    ),
  ),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: _fabColor,
    foregroundColor: const Color(0xFFFFFFFF),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_fabRadius),
    ),
  ),
);

// -- Dark --------------------------------------------------------------------

final ThemeData tropicalDark = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  extensions: const <ThemeExtension<dynamic>>[FeatureAccentColors.dark],
  colorScheme: const ColorScheme(
    brightness: Brightness.dark,
    primary: _primaryDark,
    onPrimary: Color(0xFF0A1A18),
    secondary: _secondaryDark,
    onSecondary: Color(0xFF1A0A06),
    error: _errorColor,
    onError: _onErrorColor,
    surface: _surfaceDark,
    onSurface: Color(0xFFE0F0EC),
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
    elevation: 2,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_cardRadius),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_inputRadius),
    ),
  ),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: _fabColor,
    foregroundColor: const Color(0xFFFFFFFF),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_fabRadius),
    ),
  ),
);
