import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/features/dive_computer/domain/entities/clock_sync.dart';

/// SharedPreferences layout for the clock sync settings (issue #1216).
///
/// Installation-local on purpose: whether a phone with automatic time should
/// set a computer's clock is a property of that phone, not of the diver, so
/// nothing here goes near the settings table or the sync serializer. Keeping
/// it out of `dive_computers` also sidesteps a schema rung and the whole-row
/// upsert the sync import performs on that table.
class ClockSyncPreferences {
  static const globalKey = 'dive_computer_clock_sync_enabled';
  static const overridePrefix = 'dive_computer_clock_sync_override.';
  static const supportPrefix = 'dive_computer_clock_sync_support.';

  final SharedPreferences _prefs;

  ClockSyncPreferences(this._prefs);

  ClockSyncSettings load() {
    final overrides = <String, ClockSyncOverride>{};
    final support = <String, ClockSyncSupport>{};
    for (final key in _prefs.getKeys()) {
      if (key.startsWith(overridePrefix)) {
        final value = _overrideFromName(_prefs.getString(key));
        if (value != ClockSyncOverride.inherit) {
          overrides[key.substring(overridePrefix.length)] = value;
        }
      } else if (key.startsWith(supportPrefix)) {
        final value = _supportFromName(_prefs.getString(key));
        if (value != ClockSyncSupport.unknown) {
          support[key.substring(supportPrefix.length)] = value;
        }
      }
    }
    return ClockSyncSettings(
      globalEnabled: _prefs.getBool(globalKey) ?? false,
      overrides: Map.unmodifiable(overrides),
      support: Map.unmodifiable(support),
    );
  }

  Future<void> writeGlobal(bool value) => _prefs.setBool(globalKey, value);

  Future<void> writeOverride(String computerId, ClockSyncOverride value) {
    final key = '$overridePrefix$computerId';
    return switch (value) {
      ClockSyncOverride.inherit => _prefs.remove(key),
      ClockSyncOverride.always => _prefs.setString(key, 'always'),
      ClockSyncOverride.never => _prefs.setString(key, 'never'),
    };
  }

  Future<void> writeSupport(String computerId, ClockSyncSupport value) {
    final key = '$supportPrefix$computerId';
    return switch (value) {
      ClockSyncSupport.unknown => _prefs.remove(key),
      ClockSyncSupport.supported => _prefs.setString(key, 'supported'),
      ClockSyncSupport.unsupported => _prefs.setString(key, 'unsupported'),
    };
  }

  Future<void> forget(String computerId) async {
    await _prefs.remove('$overridePrefix$computerId');
    await _prefs.remove('$supportPrefix$computerId');
  }

  static ClockSyncOverride _overrideFromName(String? name) => switch (name) {
    'always' => ClockSyncOverride.always,
    'never' => ClockSyncOverride.never,
    _ => ClockSyncOverride.inherit,
  };

  static ClockSyncSupport _supportFromName(String? name) => switch (name) {
    'supported' => ClockSyncSupport.supported,
    'unsupported' => ClockSyncSupport.unsupported,
    _ => ClockSyncSupport.unknown,
  };
}
