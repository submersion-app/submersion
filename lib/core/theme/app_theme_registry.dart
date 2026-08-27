import 'package:flutter/material.dart';
import 'package:submersion/core/theme/app_snack_bar_theme.dart';
import 'package:submersion/core/theme/app_theme_preset.dart';
import 'package:submersion/core/theme/full_themes/console_theme.dart';
import 'package:submersion/core/theme/full_themes/deep_theme.dart';
import 'package:submersion/core/theme/full_themes/minimalist_theme.dart';
import 'package:submersion/core/theme/full_themes/submersion_theme.dart';
import 'package:submersion/core/theme/full_themes/tropical_theme.dart';

class AppThemeRegistry {
  AppThemeRegistry._();

  static final List<AppThemePreset> presets = List.unmodifiable([
    _preset(
      id: 'submersion',
      nameKey: 'theme_submersion',
      light: submersionLight,
      dark: submersionDark,
    ),
    _preset(
      id: 'console',
      nameKey: 'theme_console',
      light: consoleLight,
      dark: consoleDark,
    ),
    _preset(
      id: 'tropical',
      nameKey: 'theme_tropical',
      light: tropicalLight,
      dark: tropicalDark,
    ),
    _preset(
      id: 'minimalist',
      nameKey: 'theme_minimalist',
      light: minimalistLight,
      dark: minimalistDark,
    ),
    _preset(
      id: 'deep',
      nameKey: 'theme_deep',
      light: deepLight,
      dark: deepDark,
    ),
  ]);

  /// Builds a preset with the cross-preset component defaults folded in.
  ///
  /// Applied once, at registry initialisation, rather than in [resolveTheme]:
  /// that runs on every app rebuild and would allocate a fresh [ThemeData]
  /// each time.
  static AppThemePreset _preset({
    required String id,
    required String nameKey,
    required ThemeData light,
    required ThemeData dark,
  }) {
    return AppThemePreset(
      id: id,
      nameKey: nameKey,
      lightTheme: withAppSnackBarDefaults(light),
      darkTheme: withAppSnackBarDefaults(dark),
    );
  }

  /// Find a preset by ID, falling back to Submersion if not found.
  static AppThemePreset findById(String id) {
    return presets.firstWhere((p) => p.id == id, orElse: () => presets.first);
  }

  /// Resolve the concrete ThemeData for a preset at a given brightness.
  static ThemeData resolveTheme(AppThemePreset preset, Brightness brightness) {
    return brightness == Brightness.light
        ? preset.lightTheme
        : preset.darkTheme;
  }
}
