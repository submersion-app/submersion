import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';

/// Lightroom connector scan state, keyed by connector account id.
///
/// Two storage tiers on purpose (program spec section 6):
/// - Scan CONFIGURATION (album filter, auto-poll) lives in the synced
///   `settings` table so a second device behaves identically after
///   sign-in. Values written before the sync rollout are read from
///   SharedPreferences as a fallback until the next write.
/// - Poll STATE (cursor, last error) stays in SharedPreferences: each
///   connected device polls independently, and a device that never
///   connected has no state at all (media store attach-state precedent).
class LightroomConnectorState {
  LightroomConnectorState({
    required SharedPreferences prefs,
    required String accountId,
    AppDatabase? database,
    SyncRepository? syncRepository,
  }) : _prefs = prefs,
       _accountId = accountId,
       _database = database,
       _syncRepository = syncRepository ?? SyncRepository();

  final SharedPreferences _prefs;
  final String _accountId;
  final AppDatabase? _database;
  final SyncRepository _syncRepository;

  AppDatabase get _db => _database ?? DatabaseService.instance.database;

  String get _lastPollKey => 'lightroom_${_accountId}_last_poll_at';
  String get _albumIdsKey => 'lightroom_${_accountId}_album_ids';
  String get _autoPollKey => 'lightroom_${_accountId}_auto_poll';
  String get _lastErrorKey => 'lightroom_${_accountId}_last_error';

  /// Synced settings-table keys (same names as the legacy prefs keys; the
  /// namespaces are distinct stores).
  String get _albumIdsSettingKey => _albumIdsKey;
  String get _autoPollSettingKey => _autoPollKey;

  Future<String?> _readSetting(String key) async {
    final row = await (_db.select(
      _db.settings,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  /// Whether a synced deletion tombstone exists for [key]. A tombstoned
  /// key means another device cleared this configuration: the legacy
  /// prefs fallback must NOT resurrect the old local value.
  Future<bool> _isTombstoned(String key) async {
    final rows = await _db
        .customSelect(
          "SELECT 1 FROM deletion_log "
          "WHERE entity_type = 'settings' AND record_id = ? LIMIT 1",
          variables: [Variable.withString(key)],
        )
        .get();
    return rows.isNotEmpty;
  }

  Future<void> _writeSetting(String key, String value) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db
        .into(_db.settings)
        .insertOnConflictUpdate(
          SettingsCompanion(
            key: Value(key),
            value: Value(value),
            updatedAt: Value(now),
          ),
        );
    await _syncRepository.markRecordPending(
      entityType: 'settings',
      recordId: key,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }

  Future<DateTime?> lastPollAt() async {
    final ms = _prefs.getInt(_lastPollKey);
    return ms == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }

  Future<void> setLastPollAt(DateTime t) =>
      _prefs.setInt(_lastPollKey, t.millisecondsSinceEpoch);

  /// Album ids to scan; empty means the whole catalog. Synced.
  Future<List<String>> albumIds() async {
    final raw = await _readSetting(_albumIdsSettingKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded.whereType<String>().toList(growable: false);
        }
      } on FormatException {
        // Corrupt synced value: fall through to the local fallback.
      }
    }
    // A tombstoned key was cleared on another device: honor the deletion
    // instead of resurrecting the pre-sync local value.
    if (await _isTombstoned(_albumIdsSettingKey)) return const [];
    return _prefs.getStringList(_albumIdsKey) ?? const [];
  }

  Future<void> setAlbumIds(List<String> ids) =>
      _writeSetting(_albumIdsSettingKey, jsonEncode(ids));

  /// Whether the startup auto-poll runs for this account. Synced.
  Future<bool> autoPollEnabled() async {
    final raw = await _readSetting(_autoPollSettingKey);
    // Strict parse: only the two values this class writes are meaningful;
    // anything else is corrupt and falls through like a missing row.
    if (raw == 'true') return true;
    if (raw == 'false') return false;
    if (await _isTombstoned(_autoPollSettingKey)) return true;
    return _prefs.getBool(_autoPollKey) ?? true;
  }

  Future<void> setAutoPollEnabled(bool enabled) =>
      _writeSetting(_autoPollSettingKey, enabled ? 'true' : 'false');

  /// The last scan/poll failure, surfaced as a needs-attention state in
  /// settings. Null when the last run succeeded. Per-device.
  Future<String?> lastError() async => _prefs.getString(_lastErrorKey);

  Future<void> setLastError(String? message) async {
    if (message == null) {
      await _prefs.remove(_lastErrorKey);
    } else {
      await _prefs.setString(_lastErrorKey, message);
    }
  }

  /// Removes every stored field (disconnect): local poll state plus the
  /// synced configuration rows (tombstoned so peers drop them too).
  Future<void> clear() async {
    await _prefs.remove(_lastPollKey);
    await _prefs.remove(_albumIdsKey);
    await _prefs.remove(_autoPollKey);
    await _prefs.remove(_lastErrorKey);
    for (final key in [_albumIdsSettingKey, _autoPollSettingKey]) {
      await (_db.delete(_db.settings)..where((t) => t.key.equals(key))).go();
      await _syncRepository.logDeletion(entityType: 'settings', recordId: key);
    }
    SyncEventBus.notifyLocalChange();
  }
}
