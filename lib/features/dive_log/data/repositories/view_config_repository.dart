import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_log/domain/entities/view_field_config.dart'
    as domain;

/// Repository for persisting dive list view configurations and field presets.
class ViewConfigRepository {
  final AppDatabase _db;
  final SyncRepository _syncRepository = SyncRepository();
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
  // Generic Config (entity-type-agnostic)
  // ---------------------------------------------------------------------------

  /// Returns the raw JSON config string for [diverId] and [viewModeKey], or
  /// null if none is saved. Used by generic [EntityTableConfigNotifier] with
  /// keys like `"table_sites"`, `"table_trips"`, etc.
  Future<String?> getRawConfig(String diverId, String viewModeKey) async {
    final row =
        await (_db.select(_db.viewConfigs)..where(
              (r) => r.diverId.equals(diverId) & r.viewMode.equals(viewModeKey),
            ))
            .getSingleOrNull();
    return row?.configJson;
  }

  /// Persists a raw JSON config string for [diverId] and [viewModeKey].
  Future<void> saveRawConfig(
    String diverId,
    String viewModeKey,
    String configJson,
  ) async {
    await _upsertViewConfig(
      diverId: diverId,
      viewMode: viewModeKey,
      configJson: configJson,
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
  ///
  /// On conflict (same [preset.id]), updates all fields except [createdAt] so
  /// the original creation timestamp is preserved across renames/edits.
  Future<void> savePreset(String diverId, domain.FieldPreset preset) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final companion = FieldPresetsCompanion.insert(
      id: preset.id,
      diverId: diverId,
      viewMode: preset.viewMode.name,
      name: preset.name,
      configJson: jsonEncode(preset.configJson),
      isBuiltIn: Value(preset.isBuiltIn),
      createdAt: now,
    );
    await _db
        .into(_db.fieldPresets)
        .insert(
          companion,
          onConflict: DoUpdate(
            (_) => FieldPresetsCompanion(
              diverId: Value(diverId),
              viewMode: Value(preset.viewMode.name),
              name: Value(preset.name),
              configJson: Value(jsonEncode(preset.configJson)),
              isBuiltIn: Value(preset.isBuiltIn),
              // createdAt intentionally omitted to preserve original timestamp
            ),
          ),
        );

    // Mark pending so the edit is protected during merge and gets an HLC
    // stamped onto the row. field_presets is an HLC-filtered changeset entity,
    // so an unstamped preset (hlc == null) is silently dropped from every
    // incremental sync once the base watermark is established.
    await _syncRepository.markRecordPending(
      entityType: 'fieldPresets',
      recordId: preset.id,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }

  /// Deletes the preset with [presetId] only if it is not a built-in preset.
  Future<void> deletePreset(String presetId) async {
    final deleted = await (_db.delete(
      _db.fieldPresets,
    )..where((r) => r.id.equals(presetId) & r.isBuiltIn.equals(false))).go();
    if (deleted > 0) {
      await _syncRepository.logDeletion(
        entityType: 'fieldPresets',
        recordId: presetId,
      );
      SyncEventBus.notifyLocalChange();
    }
  }

  /// Upserts built-in table presets for [diverId]. Idempotent: safe to call
  /// on every load. Uses insertOnConflictUpdate so presets are refreshed if
  /// the built-in definitions change, but createdAt is preserved by using a
  /// fixed stable timestamp per preset ID.
  Future<void> ensureBuiltInPresets(String diverId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final preset in domain.FieldPreset.builtInTablePresets()) {
      await _db
          .into(_db.fieldPresets)
          .insertOnConflictUpdate(
            FieldPresetsCompanion.insert(
              id: preset.id,
              diverId: diverId,
              viewMode: preset.viewMode.name,
              name: preset.name,
              configJson: jsonEncode(preset.configJson),
              isBuiltIn: const Value(true),
              createdAt: now,
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

    final String rowId;
    if (existing != null) {
      rowId = existing.id;
      await (_db.update(
        _db.viewConfigs,
      )..where((r) => r.id.equals(existing.id))).write(
        ViewConfigsCompanion(
          configJson: Value(configJson),
          updatedAt: Value(now),
        ),
      );
    } else {
      rowId = _uuid.v4();
      await _db
          .into(_db.viewConfigs)
          .insert(
            ViewConfigsCompanion(
              id: Value(rowId),
              diverId: Value(diverId),
              viewMode: Value(viewMode),
              configJson: Value(configJson),
              updatedAt: Value(now),
            ),
          );
    }

    // Mark pending so the edit is protected during merge and gets an HLC
    // stamped onto the row (cross-device config edits resolve by HLC).
    await _syncRepository.markRecordPending(
      entityType: 'viewConfigs',
      recordId: rowId,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
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
