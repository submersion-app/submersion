import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_computer/data/clock_sync_preferences.dart';
import 'package:submersion/features/dive_computer/domain/entities/clock_sync.dart';

/// Holds the installation-local clock sync settings (issue #1216) and writes
/// each change through to SharedPreferences.
///
/// Seeded synchronously from the store so the first frame of the computers
/// list draws the switch in the right position.
class ClockSyncSettingsNotifier extends StateNotifier<ClockSyncSettings> {
  ClockSyncSettingsNotifier(ClockSyncPreferences prefs)
    : _prefs = prefs,
      super(prefs.load());

  /// State with nothing behind it, for a container that has no
  /// SharedPreferences (a widget test, or an early frame). Writes update the
  /// state and are otherwise dropped rather than throwing.
  ClockSyncSettingsNotifier.unstored()
    : _prefs = null,
      super(const ClockSyncSettings());

  final ClockSyncPreferences? _prefs;

  Future<void> setGlobalEnabled(bool value) async {
    state = state.withGlobalEnabled(value);
    await _prefs?.writeGlobal(value);
  }

  Future<void> setOverride(String computerId, ClockSyncOverride value) async {
    state = state.withOverride(computerId, value);
    await _prefs?.writeOverride(computerId, value);
  }

  /// Remembers what the computer answered. Only synced and unsupported are
  /// definite; a failed sync leaves the record untouched.
  Future<void> recordSupport(String computerId, ClockSyncStatus status) async {
    final next = state.withSupportFromStatus(computerId, status);
    if (identical(next, state)) return;
    state = next;
    await _prefs?.writeSupport(computerId, next.supportFor(computerId));
  }

  /// Forgets a recorded answer so the next download asks the device again,
  /// for the "Check again" action after a libdivecomputer update.
  Future<void> clearSupport(String computerId) async {
    state = state.withSupport(computerId, ClockSyncSupport.unknown);
    await _prefs?.writeSupport(computerId, ClockSyncSupport.unknown);
  }

  /// Drops every key for a computer that is being deleted.
  Future<void> forget(String computerId) async {
    state = state.without(computerId);
    await _prefs?.forget(computerId);
  }
}

/// Defaults to an unstored notifier on purpose, like
/// `mediaProvenanceBadgesProvider`: this is watched from the computers list
/// and the device detail page, and `sharedPreferencesProvider` throws unless
/// the root scope overrode it, which would put those pages into an error
/// state in any container without the override. `rootProviderOverrides`
/// installs the stored notifier for the running app.
final clockSyncSettingsNotifierProvider =
    StateNotifierProvider<ClockSyncSettingsNotifier, ClockSyncSettings>(
      (ref) => ClockSyncSettingsNotifier.unstored(),
    );
