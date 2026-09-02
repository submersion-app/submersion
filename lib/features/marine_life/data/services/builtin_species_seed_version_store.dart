import 'package:shared_preferences/shared_preferences.dart';

/// Which bundled catalog version this device has applied. Device-local by
/// design: the catalog is re-seeded on every install, so nothing about it
/// syncs. Restore-from-backup clears it (BackupService) so a restored older
/// database is upgraded again on the next launch.
abstract class BuiltInSpeciesSeedVersionStore {
  Future<int> appliedVersion();
  Future<void> markApplied(int version);
  Future<void> clear();
}

class PrefsBuiltInSpeciesSeedVersionStore
    implements BuiltInSpeciesSeedVersionStore {
  PrefsBuiltInSpeciesSeedVersionStore(this._prefs);

  static const key = 'builtin_species_seed_version';

  final SharedPreferences _prefs;

  @override
  Future<int> appliedVersion() async {
    try {
      return _prefs.getInt(key) ?? 0;
    } catch (_) {
      // A value of another type reads as never applied.
      return 0;
    }
  }

  @override
  Future<void> markApplied(int version) => _prefs.setInt(key, version);

  @override
  Future<void> clear() => _prefs.remove(key);
}
