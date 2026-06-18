import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences flag set when a Merge restore completes, consumed once on
/// the next launch to force a sync that bypasses the first-contact gate.
///
/// Deliberately OUTSIDE the database (mirrors the pending-replace intent in
/// LibraryEpochStore): the restore rewinds the in-DB sync cursor, and the
/// Merge path mints no epoch, so this is the only durable signal that the
/// just-restored data still owes the cloud one reconciling sync.
class PostRestoreSyncStore {
  static const _pendingKey = 'sync_post_restore_pending';

  final SharedPreferences _prefs;

  PostRestoreSyncStore(this._prefs);

  bool get pending => _prefs.getBool(_pendingKey) ?? false;

  Future<void> setPending() async {
    await _prefs.setBool(_pendingKey, true);
  }

  Future<void> clear() async {
    await _prefs.remove(_pendingKey);
  }
}
