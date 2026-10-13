import 'package:shared_preferences/shared_preferences.dart';

/// Whether the next launch should compact the database, and how long a
/// failed compaction holds automatic ones off (issue #3333).
///
/// Per device and never synced: free pages are a fact about this device's
/// file, not about the dive log.
class DatabaseCompactionPrefs {
  DatabaseCompactionPrefs(this._prefs, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  static const requestedKey = 'compactDatabaseAtNextLaunch';
  static const backoffKey = 'compactDatabaseBackoffUntil';

  /// After a failure (a busy lock, too little space for the rewrite) a
  /// nearly full device would otherwise fail again on every launch.
  static const backoff = Duration(days: 7);

  final SharedPreferences _prefs;
  final DateTime Function() _now;

  bool get isRequested => _prefs.getBool(requestedKey) ?? false;

  bool get inBackoff {
    final until = _prefs.getInt(backoffKey);
    return until != null && _now().millisecondsSinceEpoch < until;
  }

  Future<void> request() => _prefs.setBool(requestedKey, true);

  Future<void> cancel() => _prefs.remove(requestedKey);

  /// The diver withdrew a scheduled compaction. Held off like a failure,
  /// so the app's own check does not schedule it straight back; a manual
  /// Compact still works.
  Future<void> decline() async {
    await cancel();
    await recordFailure();
  }

  Future<void> recordFailure() =>
      _prefs.setInt(backoffKey, _now().add(backoff).millisecondsSinceEpoch);
}
