import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Whether media grids show a provenance badge on every thumbnail.
///
/// Health badges (missing, uploading, not backed up) are NOT covered by this
/// switch. Those report a problem the diver may need to act on, and hiding
/// them behind a display preference would let a broken photo look healthy.
/// This only silences the always-on "where did these bytes come from" glyph.
///
/// Deliberately kept off AppSettings, matching [DisplayZoomNotifier]: this is
/// device-local rather than per-diver, since whether a grid is decorated is a
/// property of the screen you are looking at, not of the person. It also
/// avoids a settings-table column, which would claim a schema version two
/// unmerged branches already claim.
///
/// Seeded synchronously from SharedPreferences so the first frame of a grid
/// draws with the right answer instead of flashing badges on and then off.
class MediaProvenanceBadgesNotifier extends StateNotifier<bool> {
  MediaProvenanceBadgesNotifier(SharedPreferences prefs)
    : _prefs = prefs,
      super(prefs.getBool(SettingsKeys.mediaProvenanceBadges) ?? true);

  /// Fixed state with nothing behind it.
  ///
  /// Used when SharedPreferences is unavailable: a widget test with no
  /// binding, or an early frame before initialization. [setEnabled] becomes a
  /// no-op rather than throwing, so a toggle in that state fails quietly
  /// instead of taking a screen down.
  MediaProvenanceBadgesNotifier.unstored(super.enabled) : _prefs = null;

  final SharedPreferences? _prefs;

  Future<void> setEnabled(bool value) async {
    if (state == value) return;
    state = value;
    await _prefs?.setBool(SettingsKeys.mediaProvenanceBadges, value);
  }
}

/// Defaults to enabled, with no storage behind it.
///
/// Deliberately does NOT reach for [sharedPreferencesProvider] itself. This is
/// watched from inside a grid TILE, and that provider throws unless the root
/// scope overrode it, so a container without the override would put every
/// thumbnail into an error state. Neither `watch` nor `read` can be defended
/// against here: a dependency's error becomes this provider's own error state,
/// which no try/catch in the create function intercepts.
///
/// `rootProviderOverrides` swaps in the stored-value notifier, so production
/// reads and writes the preference while any container without that override
/// simply renders badges. Enabled is the harmless direction for a decoration.
final mediaProvenanceBadgesProvider =
    StateNotifierProvider<MediaProvenanceBadgesNotifier, bool>(
      (ref) => MediaProvenanceBadgesNotifier.unstored(true),
    );
