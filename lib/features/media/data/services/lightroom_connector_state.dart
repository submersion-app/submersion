import 'package:shared_preferences/shared_preferences.dart';

/// Per-device Lightroom connector scan state, keyed by connector account
/// id. Lives in SharedPreferences (not the synced database) on purpose:
/// each connected device polls independently, and a device that never
/// connected has no state at all. Mirrors the media store's attach-state
/// precedent.
class LightroomConnectorState {
  LightroomConnectorState({
    required SharedPreferences prefs,
    required String accountId,
  }) : _prefs = prefs,
       _accountId = accountId;

  final SharedPreferences _prefs;
  final String _accountId;

  String get _lastPollKey => 'lightroom_${_accountId}_last_poll_at';
  String get _albumIdsKey => 'lightroom_${_accountId}_album_ids';
  String get _autoPollKey => 'lightroom_${_accountId}_auto_poll';
  String get _lastErrorKey => 'lightroom_${_accountId}_last_error';

  Future<DateTime?> lastPollAt() async {
    final ms = _prefs.getInt(_lastPollKey);
    return ms == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }

  Future<void> setLastPollAt(DateTime t) =>
      _prefs.setInt(_lastPollKey, t.millisecondsSinceEpoch);

  /// Album ids to scan; empty means the whole catalog.
  Future<List<String>> albumIds() async =>
      _prefs.getStringList(_albumIdsKey) ?? const [];

  Future<void> setAlbumIds(List<String> ids) =>
      _prefs.setStringList(_albumIdsKey, ids);

  Future<bool> autoPollEnabled() async => _prefs.getBool(_autoPollKey) ?? true;

  Future<void> setAutoPollEnabled(bool enabled) =>
      _prefs.setBool(_autoPollKey, enabled);

  /// The last scan/poll failure, surfaced as a needs-attention state in
  /// settings. Null when the last run succeeded.
  Future<String?> lastError() async => _prefs.getString(_lastErrorKey);

  Future<void> setLastError(String? message) async {
    if (message == null) {
      await _prefs.remove(_lastErrorKey);
    } else {
      await _prefs.setString(_lastErrorKey, message);
    }
  }

  /// Removes every stored field (disconnect).
  Future<void> clear() async {
    await _prefs.remove(_lastPollKey);
    await _prefs.remove(_albumIdsKey);
    await _prefs.remove(_autoPollKey);
    await _prefs.remove(_lastErrorKey);
  }
}
