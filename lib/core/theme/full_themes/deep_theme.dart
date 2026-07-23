import 'package:flutter/material.dart';
import 'package:submersion/core/theme/feature_accent_colors.dart';

// ---------------------------------------------------------------------------
// Deep Theme -- immersive, deep ocean feel
// Semi-transparent cards, bold headers, rich blues.
// ---------------------------------------------------------------------------

// -- Colors ------------------------------------------------------------------

const _surfaceLight = Color(0xFFE8F0F8);
const _surfaceDark = Color(0xFF080E18);

const _appBarLight = Color(0xFF0A1628);
const _appBarDark = Color(0xFF0A1428);

const _primaryLight = Color(0xFF2070C0);
const _primaryDark = Color(0xFF40A0E8);

const _cardLight = Color(0xFFF0F4F8);
const Color _cardDark = Color.fromRGBO(15, 30, 55, 0.7);

const _cardBorderColor = Color(0x263C78B4);

const _fabColor = Color(0xFF2070C0);

const _errorColor = Color(0xFFB00020);
const _onErrorColor = Color(0xFFFFFFFF);

// -- Shared shape constants --------------------------------------------------

const _cardRadius = 16.0;
const _fabRadius = 16.0;
const _inputRadius = 12.0;

// -- Text themes -------------------------------------------------------------

TextTheme _buildTextTheme(Brightness brightness) {
  final base = brightness == Brightness.light
      ? ThemeData.light().textTheme
      : ThemeData.dark().textTheme;

  return base.copyWith(
    displayLarge: base.displayLarge?.copyWith(fontWeight: FontWeight.w700),
    displayMedium: base.displayMedium?.copyWith(fontWeight: FontWeight.w700),
    displaySmall: base.displaySmall?.copyWith(fontWeight: FontWeight.w700),
    headlineLarge: base.headlineLarge?.copyWith(fontWeight: FontWeight.w700),
    headlineMedium: base.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
    headlineSmall: base.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
    titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w700),
    titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w700),
  );
}

// -- Light -------------------------------------------------------------------

final ThemeData deepLight = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  extensions: const <ThemeExtension<dynamic>>[FeatureAccentColors.light],
  colorScheme: const ColorScheme(
    brightness: Brightness.light,
    primary: _primaryLight,
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFF1858A0),
    onSecondary: Color(0xFFFFFFFF),
    error: _errorColor,
    onError: _onErrorColor,
    surface: _surfaceLight,
    onSurface: Color(0xFF0A1628),
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
    elevation: 1,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_cardRadius),
      side: const BorderSide(color: _cardBorderColor),
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

final ThemeData deepDark = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  extensions: const <ThemeExtension<dynamic>>[FeatureAccentColors.dark],
  colorScheme: const ColorScheme(
    brightness: Brightness.dark,
    primary: _primaryDark,
    onPrimary: Color(0xFF0A1428),
    secondary: Color(0xFF3080D0),
    onSecondary: Color(0xFFFFFFFF),
    error: _errorColor,
    onError: _onErrorColor,
    surface: _surfaceDark,
    onSurface: Color(0xFFD0E0F0),
    surfaceContainerLow: Color(0xFF0F1E37),
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
      side: const BorderSide(color: _cardBorderColor),
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
