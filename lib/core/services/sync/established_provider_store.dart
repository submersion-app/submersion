import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences set of cloud providerIds this install has completed a
/// successful sync against.
///
/// Lives outside the database so a restore (which rewinds the in-DB sync
/// cursor) cannot make an established device look like a brand-new one to the
/// first-contact gate. Same survive-the-restore role as the device-id / epoch
/// anchors. Keyed on the providerId used by `getLastSyncTime(forProvider:)`,
/// so the gate stays correct across backend switches.
class EstablishedProviderStore {
  static const _key = 'sync_established_providers';

  final SharedPreferences _prefs;

  EstablishedProviderStore(this._prefs);

  bool contains(String providerId) =>
      (_prefs.getStringList(_key) ?? const <String>[]).contains(providerId);

  Future<void> add(String providerId) async {
    final current = _prefs.getStringList(_key) ?? const <String>[];
    if (current.contains(providerId)) return;
    await _prefs.setStringList(_key, [...current, providerId]);
  }

  Future<void> clear() async {
    await _prefs.remove(_key);
  }
}
