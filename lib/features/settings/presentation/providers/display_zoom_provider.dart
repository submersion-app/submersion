import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/theme/display_zoom.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// App-wide display zoom, stored per device.
///
/// Deliberately kept off AppSettings: zoom is device-local rather than
/// per-diver, and SettingsNotifier awaits a database round-trip before it
/// reads SharedPreferences, which would make the first frames render at 100%
/// before snapping to the stored value. Seeding from SharedPreferences in the
/// constructor makes the correct zoom available on frame one.
class DisplayZoomNotifier extends StateNotifier<double> {
  DisplayZoomNotifier(this._prefs)
    : super(
        DisplayZoom.normalize(
          _prefs.getDouble(SettingsKeys.displayZoom) ??
              DisplayZoom.defaultValue,
        ),
      );

  final SharedPreferences _prefs;

  /// Updates the live zoom without touching storage.
  ///
  /// Used while a slider drag is in flight: the whole app rescales on every
  /// notch, but only the commit at the end of the drag is persisted. Keeping
  /// the write out of the drag avoids a burst of platform-channel writes whose
  /// completion order would otherwise decide what ends up stored.
  void previewZoom(double value) {
    state = DisplayZoom.normalize(value);
  }

  /// Updates the live zoom and commits it to storage.
  Future<void> setZoom(double value) async {
    final normalized = DisplayZoom.normalize(value);
    state = normalized;
    // Compared against what is stored rather than against [state], so a commit
    // that follows previewZoom to the same value still persists.
    if (_prefs.getDouble(SettingsKeys.displayZoom) == normalized) return;
    await _prefs.setDouble(SettingsKeys.displayZoom, normalized);
  }

  /// Moves one [DisplayZoom.step] in [direction] (+1 larger, -1 smaller).
  Future<void> stepBy(int direction) =>
      setZoom(state + direction * DisplayZoom.step);

  Future<void> reset() => setZoom(DisplayZoom.defaultValue);
}

final displayZoomNotifierProvider =
    StateNotifierProvider<DisplayZoomNotifier, double>((ref) {
      return DisplayZoomNotifier(ref.watch(sharedPreferencesProvider));
    });
