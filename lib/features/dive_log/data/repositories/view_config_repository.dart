import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/domain/entities/view_field_config.dart'
    as domain;

/// Repository for persisting dive list view configurations and field presets.
class ViewConfigRepository {
  final AppDatabase _db;
  static const _uuid = Uuid();

  ViewConfigRepository(this._db);

  // ---------------------------------------------------------------------------
  // Table Config
  // ---------------------------------------------------------------------------

  /// Returns the saved [domain.TableViewConfig] for [diverId], or the default.
  Future<domain.TableViewConfig> getTableConfig(String diverId) async {
    final row =
        await (_db.select(_db.viewConfigs)..where(
              (r) =>
                  r.diverId.equals(diverId) &
                  r.viewMode.equals(ListViewMode.table.name),
            ))
            .getSingleOrNull();

    if (row == null) return domain.TableViewConfig.defaultConfig();
    return domain.TableViewConfig.fromJson(
      jsonDecode(row.configJson) as Map<String, dynamic>,
    );
  }

  /// Persists [config] as the active table config for [diverId].
  Future<void> saveTableConfig(
    String diverId,
    domain.TableViewConfig config,
  ) async {
    await _upsertViewConfig(
      diverId: diverId,
      viewMode: ListViewMode.table.name,
      configJson: jsonEncode(config.toJson()),
    );
  }

  // ---------------------------------------------------------------------------
  // Card Config
  // ---------------------------------------------------------------------------

  /// Returns the saved [domain.CardViewConfig] for [diverId] and [mode], or
  /// the appropriate default if none is saved.
  Future<domain.CardViewConfig> getCardConfig(
    String diverId,
    ListViewMode mode,
  ) async {
    final row =
        await (_db.select(_db.viewConfigs)..where(
              (r) => r.diverId.equals(diverId) & r.viewMode.equals(mode.name),
            ))
            .getSingleOrNull();

    if (row == null) return _defaultCardConfig(mode);
    return domain.CardViewConfig.fromJson(
      jsonDecode(row.configJson) as Map<String, dynamic>,
    );
  }

  /// Persists [config] as the active card config for [diverId].
  Future<void> saveCardConfig(
    String diverId,
    domain.CardViewConfig config,
  ) async {
    await _upsertViewConfig(
      diverId: diverId,
      viewMode: config.mode.name,
      configJson: jsonEncode(config.toJson()),
    );
  }

  // ---------------------------------------------------------------------------
  // Presets
  // ---------------------------------------------------------------------------

  /// Returns all [domain.FieldPreset]s for [diverId] and [mode], ordered by
  /// creation time.
  Future<List<domain.FieldPreset>> getPresetsForMode(
    String diverId,
    ListViewMode mode,
  ) async {
    final rows =
        await (_db.select(_db.fieldPresets)
              ..where(
                (r) => r.diverId.equals(diverId) & r.viewMode.equals(mode.name),
              )
              ..orderBy([(r) => OrderingTerm.asc(r.createdAt)]))
            .get();

    return rows.map(_mapRowToPreset).toList();
  }

  /// Upserts [preset] for [diverId] into the field presets table.
  Future<void> savePreset(String diverId, domain.FieldPreset preset) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db
        .into(_db.fieldPresets)
        .insertOnConflictUpdate(
          FieldPresetsCompanion(
            id: Value(preset.id),
            diverId: Value(diverId),
            viewMode: Value(preset.viewMode.name),
            name: Value(preset.name),
            configJson: Value(jsonEncode(preset.configJson)),
            isBuiltIn: Value(preset.isBuiltIn),
            createdAt: Value(now),
          ),
        );
  }

  /// Deletes the preset with [presetId] only if it is not a built-in preset.
  Future<void> deletePreset(String presetId) async {
    await (_db.delete(
      _db.fieldPresets,
    )..where((r) => r.id.equals(presetId) & r.isBuiltIn.equals(false))).go();
  }

  /// Inserts built-in table presets for [diverId] if they do not already exist.
  Future<void> ensureBuiltInPresets(String diverId) async {
    final existing =
        await (_db.select(_db.fieldPresets)..where(
              (r) => r.diverId.equals(diverId) & r.isBuiltIn.equals(true),
            ))
            .get();

    if (existing.isNotEmpty) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    for (final preset in domain.FieldPreset.builtInTablePresets()) {
      await _db
          .into(_db.fieldPresets)
          .insert(
            FieldPresetsCompanion(
              id: Value(preset.id),
              diverId: Value(diverId),
              viewMode: Value(preset.viewMode.name),
              name: Value(preset.name),
              configJson: Value(jsonEncode(preset.configJson)),
              isBuiltIn: Value(preset.isBuiltIn),
              createdAt: Value(now),
            ),
          );
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<void> _upsertViewConfig({
    required String diverId,
    required String viewMode,
    required String configJson,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    final existing =
        await (_db.select(_db.viewConfigs)..where(
              (r) => r.diverId.equals(diverId) & r.viewMode.equals(viewMode),
            ))
            .getSingleOrNull();

    if (existing != null) {
      await (_db.update(
        _db.viewConfigs,
      )..where((r) => r.id.equals(existing.id))).write(
        ViewConfigsCompanion(
          configJson: Value(configJson),
          updatedAt: Value(now),
        ),
      );
    } else {
      await _db
          .into(_db.viewConfigs)
          .insert(
            ViewConfigsCompanion(
              id: Value(_uuid.v4()),
              diverId: Value(diverId),
              viewMode: Value(viewMode),
              configJson: Value(configJson),
              updatedAt: Value(now),
            ),
          );
    }
  }

  domain.CardViewConfig _defaultCardConfig(ListViewMode mode) {
    switch (mode) {
      case ListViewMode.compact:
        return domain.CardViewConfig.defaultCompact();
      case ListViewMode.dense:
        return domain.CardViewConfig.defaultDense();
      case ListViewMode.detailed:
        return domain.CardViewConfig.defaultDetailed();
      case ListViewMode.table:
        return domain.CardViewConfig.defaultDetailed();
    }
  }

  domain.FieldPreset _mapRowToPreset(FieldPreset row) {
    return domain.FieldPreset(
      id: row.id,
      name: row.name,
      viewMode: ListViewMode.fromName(row.viewMode),
      configJson: jsonDecode(row.configJson) as Map<String, dynamic>,
      isBuiltIn: row.isBuiltIn,
    );
  }
}
