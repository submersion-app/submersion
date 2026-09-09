import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/theme/app_theme_preset.dart';
import 'package:submersion/core/theme/app_theme_registry.dart';

/// SharedPreferences key mirroring the active diver's theme preset.
///
/// The companion of `cachedThemeModeKey`, and it exists for the same reason:
/// the authoritative setting lives in the per-diver settings table, which the
/// startup splash cannot read because the database is not open yet. Without
/// the mirror the splash could only guess a preset, and a diver on Console or
/// Deep would meet an ocean-blue error screen.
///
/// The settings notifier writes it on every change and every hydration, so it
/// is stale for at most one launch.
const String cachedThemePresetKey = 'cached_theme_preset';

/// Resolves the theme preset for surfaces that render before the database
/// opens. A missing key, or one naming a preset this build no longer ships,
/// falls back to the default preset.
///
/// Resolution deliberately happens here rather than at the write, so the
/// mirror keeps the diver's actual choice even while a build that cannot
/// honour it is running.
AppThemePreset resolveStartupThemePreset(SharedPreferences prefs) {
  final id = prefs.getString(cachedThemePresetKey);
  return id == null
      ? AppThemeRegistry.presets.first
      : AppThemeRegistry.findById(id);
}
