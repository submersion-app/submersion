import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/gas_calculators/domain/blending/blender_preferences.dart';

/// Read/write global (not per-diver) app settings stored in the
/// key-value `settings` table.
class AppSettingsRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  static final _log = LoggerService.forClass(AppSettingsRepository);

  static const _shareByDefaultKey = 'share_new_records_by_default';
  static const _navPrimaryIdsKey = 'nav_primary_ids';
  static const _blenderPrefsKey = 'gas_blender_prefs';

  /// Emits whenever the `settings` table changes so providers holding a
  /// setting refresh after a sync applies a remote change.
  ///
  /// Emits nothing when the database is not up, matching the contract every
  /// read in this class already keeps: [getShareByDefault] and friends catch
  /// their own errors and fall back to a default rather than failing the
  /// caller. A tick that threw here would take that robustness away -- a
  /// settings-backed provider that used to resolve to its default before the
  /// database was initialised would start erroring instead, which is exactly
  /// what happens during the null-database window of a restore.
  Stream<void> watchSettingsChanges() {
    final db = DatabaseService.instance.databaseOrNull;
    if (db == null) return const Stream.empty();
    return db.tableUpdates(TableUpdateQuery.onTable(db.settings));
  }

  /// Returns the raw stored nav primary ids, or `null` if unset / on read error.
  ///
  /// Caller should normalize via `normalizeNavPrimaryIds` before using the result.
  Future<List<String>?> getNavPrimaryIdsRaw() async {
    try {
      final row = await (_db.select(
        _db.settings,
      )..where((t) => t.key.equals(_navPrimaryIdsKey))).getSingleOrNull();
      if (row == null) return null;
      final raw = row.value;
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      return decoded.whereType<String>().toList(growable: false);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to read $_navPrimaryIdsKey',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Persists the nav primary ids as a JSON-encoded string in the settings table.
  Future<void> setNavPrimaryIds(List<String> ids) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _db
          .into(_db.settings)
          .insertOnConflictUpdate(
            SettingsCompanion(
              key: const Value(_navPrimaryIdsKey),
              value: Value(jsonEncode(ids)),
              updatedAt: Value(now),
            ),
          );
      await _syncRepository.markRecordPending(
        entityType: 'settings',
        recordId: _navPrimaryIdsKey,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to write $_navPrimaryIdsKey',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// The blender's saved templates, gas prices and blending conditions.
  ///
  /// Returns null when the key has never been written, which is what lets the
  /// caller seed the default templates exactly once. A read error also returns
  /// null rather than throwing, matching every other read in this class.
  Future<BlenderPreferences?> getBlenderPreferences() async {
    try {
      final row = await (_db.select(
        _db.settings,
      )..where((t) => t.key.equals(_blenderPrefsKey))).getSingleOrNull();
      final raw = row?.value;
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return BlenderPreferences.fromJson(decoded);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to read $_blenderPrefsKey',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Persist the blender preferences. Rethrows so a failed save is visible,
  /// matching [setNavPrimaryIds].
  Future<void> setBlenderPreferences(BlenderPreferences prefs) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _db
          .into(_db.settings)
          .insertOnConflictUpdate(
            SettingsCompanion(
              key: const Value(_blenderPrefsKey),
              value: Value(jsonEncode(prefs.toJson())),
              updatedAt: Value(now),
            ),
          );
      await _syncRepository.markRecordPending(
        entityType: 'settings',
        recordId: _blenderPrefsKey,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to write $_blenderPrefsKey',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Whether newly created sites and trips default to shared.
  /// Returns `false` when the key has never been set.
  ///
  /// Reads are intentionally non-throwing: a failed read degrades to the
  /// safe default (not shared) so the UI can render without blocking on
  /// a transient DB error. Writes (via [setShareByDefault]) do rethrow so
  /// the user sees when a toggle change did not take.
  Future<bool> getShareByDefault() async {
    try {
      final row = await (_db.select(
        _db.settings,
      )..where((t) => t.key.equals(_shareByDefaultKey))).getSingleOrNull();
      return row?.value == 'true';
    } catch (e, stackTrace) {
      _log.error(
        'Failed to read $_shareByDefaultKey',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<void> setShareByDefault(bool value) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _db
          .into(_db.settings)
          .insertOnConflictUpdate(
            SettingsCompanion(
              key: const Value(_shareByDefaultKey),
              value: Value(value ? 'true' : 'false'),
              updatedAt: Value(now),
            ),
          );
      await _syncRepository.markRecordPending(
        entityType: 'settings',
        recordId: _shareByDefaultKey,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to write $_shareByDefaultKey',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Returns the raw stored value for [key], or `null` if unset or on a read
  /// error.
  ///
  /// Generic because the backing table is a key-value store; callers own the
  /// key name and any parsing (same idiom as [getNavPrimaryIdsRaw]). Reads are
  /// non-throwing so a caller can degrade to its own safe default rather than
  /// block on a transient DB error.
  Future<String?> getRawSetting(String key) async {
    try {
      final row = await (_db.select(
        _db.settings,
      )..where((t) => t.key.equals(key))).getSingleOrNull();
      return row?.value;
    } catch (e, stackTrace) {
      _log.error('Failed to read $key', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Writes [value] under [key] and stages the row for sync.
  ///
  /// Writes rethrow (unlike reads) so a caller can tell the user their change
  /// did not take.
  Future<void> setRawSetting(String key, String value) async {
    try {
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
    } catch (e, stackTrace) {
      _log.error('Failed to write $key', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
}
