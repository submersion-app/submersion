import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences key mirroring the active diver's theme-mode setting.
///
/// The authoritative setting lives in the per-diver settings table, which is
/// unavailable while the startup splash is showing (the database is not open
/// yet). The settings notifier writes this mirror on every change and every
/// hydration, so it is stale for at most one launch after a restore or sync
/// changes the setting behind the app's back.
const String cachedThemeModeKey = 'cached_theme_mode';

/// Serializes [mode] for storage under [cachedThemeModeKey].
String cachedThemeModeValue(ThemeMode mode) => switch (mode) {
  ThemeMode.system => 'system',
  ThemeMode.light => 'light',
  ThemeMode.dark => 'dark',
};

/// Resolves the brightness the app will use once its theme loads, for
/// surfaces that render before the database opens (startup splash, setup
/// wizard). A missing or unrecognized cached value falls back to
/// [platformBrightness].
Brightness resolveStartupBrightness(
  SharedPreferences prefs,
  Brightness platformBrightness,
) {
  return switch (prefs.getString(cachedThemeModeKey)) {
    'light' => Brightness.light,
    'dark' => Brightness.dark,
    _ => platformBrightness,
  };
}
