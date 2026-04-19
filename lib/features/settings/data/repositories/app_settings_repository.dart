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
