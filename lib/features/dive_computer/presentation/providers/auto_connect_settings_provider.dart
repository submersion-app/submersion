import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Whether this device passively scans for known dive computers while the
/// Transfer tab's Dive Computers section is visible, auto-connecting and
/// downloading when one is reachable (issue #3361).
///
/// Deliberately kept off AppSettings, matching [ClockSyncSettingsNotifier]:
/// this is device-local rather than per-diver, since whether this device
/// scans is a property of the hardware you are holding, not of the diver's
/// profile. The per-device opt-out that excludes a single computer from
/// auto-download regardless of this switch is a separate, synced field on
/// `DiveComputer` instead.
///
/// Seeded synchronously from SharedPreferences so the first frame of the
/// Computers section draws the switch in the right position.
class AutoConnectKnownComputersNotifier extends StateNotifier<bool> {
  AutoConnectKnownComputersNotifier(SharedPreferences prefs)
    : _prefs = prefs,
      super(prefs.getBool(SettingsKeys.autoConnectKnownComputers) ?? true);

  /// Fixed state with nothing behind it, for a container with no
  /// SharedPreferences (a widget test, or an early frame). [setEnabled]
  /// becomes a no-op rather than throwing.
  AutoConnectKnownComputersNotifier.unstored(super.enabled) : _prefs = null;

  final SharedPreferences? _prefs;

  Future<void> setEnabled(bool value) async {
    if (state == value) return;
    state = value;
    await _prefs?.setBool(SettingsKeys.autoConnectKnownComputers, value);
  }
}

/// Defaults to enabled, with no storage behind it.
///
/// `rootProviderOverrides` swaps in the stored-value notifier, so production
/// reads and writes the preference while any container without that override
/// simply scans by default - the harmless direction, matching the default
/// decided for this switch.
final autoConnectKnownComputersProvider =
    StateNotifierProvider<AutoConnectKnownComputersNotifier, bool>(
      (ref) => AutoConnectKnownComputersNotifier.unstored(true),
    );
