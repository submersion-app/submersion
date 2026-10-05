import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:submersion/core/theme/feature_accent_colors.dart';
import 'package:submersion/core/theme/status_colors.dart';
import 'package:submersion/core/theme/tinted_containers.dart';

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

// The app-bar navy sits a step from the dark surface (1.10:1), so it cannot
// double as the dark secondary; a mid slate keeps the instrument-panel tone.
const _secondaryDark = Color(0xFF8FA6BF);

const _onPrimaryLight = Color(0xFFFFFFFF);
const _onPrimaryDark = Color(0xFF0A1018);

const _cardLight = Color(0xFFFFFFFF);
const _cardDark = Color(0xFF1A2230);

// Dark mode needs its own tertiary. Left unset, ColorScheme falls back to
// secondary, which was once the app-bar navy, the same colour as _cardDark, so
// every tertiary label on a card was invisible (issue #2956). Light mode's
// fallback (_appBarLight on white) already reads, so it stays unset. The mid
// blue reads as text on cards (4.7:1), and dark onTertiary text reads on it
// (5.6:1) where white would fall short of 4.5:1 for small badge labels.
const _tertiaryDark = Color(0xFF4A90D0);

const _cardBorderLight = Color(0xFFD0D8E0);
const _cardBorderDark = Color(0xFF2A3A4A);

const _fabLight = Color(0xFF1A2230);
const _fabDark = Color(0xFF4AE0C0);

const _errorColor = Color(0xFFB00020);
const _onErrorColor = Color(0xFFFFFFFF);

// A dark surface needs a light error: #B00020 reads at under 3:1 on it.
// Matches the seeded Submersion dark theme's error tone.
const _errorDark = Color(0xFFFFB4AB);
const _onErrorDark = Color(0xFF690005);

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
  extensions: const <ThemeExtension<dynamic>>[
    FeatureAccentColors.light,
    StatusColors.light,
  ],
  colorScheme: withTintedContainers(
    const ColorScheme(
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
  extensions: const <ThemeExtension<dynamic>>[
    FeatureAccentColors.dark,
    StatusColors.dark,
  ],
  colorScheme: withTintedContainers(
    const ColorScheme(
      brightness: Brightness.dark,
      primary: _primaryDark,
      onPrimary: _onPrimaryDark,
      secondary: _secondaryDark,
      onSecondary: _onPrimaryDark,
      tertiary: _tertiaryDark,
      onTertiary: _onPrimaryDark,
      error: _errorDark,
      onError: _onErrorDark,
      surface: _surfaceDark,
      onSurface: Color(0xFFE0E4E8),
      surfaceContainerLow: _cardDark,
    ),
    // Selection indicators fill with secondaryContainer; tinting them from
    // the teal primary keeps them in the theme's accent.
    secondaryAccent: _primaryDark,
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
