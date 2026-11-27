import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/platform/host_platform.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// A device-local on/off switch kept in SharedPreferences, on by default
/// (issue #5104). Saves before it announces, so a provider that reads the
/// preference on the change sees the new value.
class FirmwareSwitchNotifier extends StateNotifier<bool> {
  FirmwareSwitchNotifier(this._prefs, this._key)
    : super(_prefs.getBool(_key) ?? true);

  final SharedPreferences _prefs;
  final String _key;

  Future<void> set(bool on) async {
    await _prefs.setBool(_key, on);
    state = on;
  }
}

/// "Check for firmware updates": whether this device reads the public
/// firmware catalogue. Off means no network call and no update notices.
final firmwareChecksEnabledProvider =
    StateNotifierProvider<FirmwareSwitchNotifier, bool>(
      (ref) => FirmwareSwitchNotifier(
        ref.watch(sharedPreferencesProvider),
        SettingsKeys.firmwareChecksEnabled,
      ),
    );

/// "Firmware update notifications": a system notification once per item and
/// new release.
final firmwareNotificationsEnabledProvider =
    StateNotifierProvider<FirmwareSwitchNotifier, bool>(
      (ref) => FirmwareSwitchNotifier(
        ref.watch(sharedPreferencesProvider),
        SettingsKeys.firmwareNotificationsEnabled,
      ),
    );

/// Whether this device shows system notifications at all: only iOS and
/// Android do (`NotificationService`). A provider so tests can pin it.
final firmwareNotificationsSupportedProvider = Provider<bool>(
  (ref) => HostPlatform.isMobile,
);
