import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/universal_import/data/csv/presets/csv_preset.dart'
    as domain;

/// Repository for persisting user-saved CSV import presets.
///
/// Presets are local-only (not synced). Each row stores the full preset as a
/// JSON blob in the `preset_json` column, with `id` and `name` duplicated at
/// the table level for efficient queries.
class CsvPresetRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final _log = LoggerService.forClass(CsvPresetRepository);

  /// Returns all user-saved presets, ordered by name.
  Future<List<domain.CsvPreset>> getAllPresets() async {
    try {
      final query = _db.select(_db.csvPresets)
        ..orderBy([(t) => OrderingTerm.asc(t.name)]);
      final rows = await query.get();
      return rows
          .map((row) => domain.CsvPreset.fromJson(row.presetJson))
          .toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get all CSV presets',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Inserts or updates a preset. The full preset is serialized to JSON.
  Future<void> savePreset(domain.CsvPreset preset) async {
    try {
      _log.info('Saving CSV preset: ${preset.name} (${preset.id})');
      final now = DateTime.now().millisecondsSinceEpoch;

      final json = preset.toJson();
      await _db
          .into(_db.csvPresets)
          .insert(
            CsvPresetsCompanion(
              id: Value(preset.id),
              name: Value(preset.name),
              presetJson: Value(json),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
            onConflict: DoUpdate(
              (old) => CsvPresetsCompanion(
                name: Value(preset.name),
                presetJson: Value(json),
                updatedAt: Value(now),
              ),
            ),
          );

      _log.info('Saved CSV preset: ${preset.id}');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to save CSV preset: ${preset.id}',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Deletes a preset by its id.
  Future<void> deletePreset(String id) async {
    try {
      _log.info('Deleting CSV preset: $id');
      await (_db.delete(_db.csvPresets)..where((t) => t.id.equals(id))).go();
      _log.info('Deleted CSV preset: $id');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to delete CSV preset: $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
