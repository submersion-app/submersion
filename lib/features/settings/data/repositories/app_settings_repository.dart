import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';

/// Read/write global (not per-diver) app settings stored in the
/// key-value `settings` table.
class AppSettingsRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  static final _log = LoggerService.forClass(AppSettingsRepository);

  static const _shareByDefaultKey = 'share_new_records_by_default';
  static const _navPrimaryIdsKey = 'nav_primary_ids';

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
    } catch (e, stackTrace) {
      _log.error(
        'Failed to write $_navPrimaryIdsKey',
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
    } catch (e, stackTrace) {
      _log.error(
        'Failed to write $_shareByDefaultKey',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
