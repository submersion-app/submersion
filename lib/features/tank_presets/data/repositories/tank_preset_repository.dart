import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/tank_presets.dart' as constants;
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';

class TankPresetRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(TankPresetRepository);

  // ============================================================================
  // CRUD Operations
  // ============================================================================

  /// Get all tank presets (custom + built-in), with custom presets first
  /// If no diverId is provided, returns only built-in presets
  Future<List<TankPresetEntity>> getAllPresets({String? diverId}) async {
    try {
      final customPresets = await getCustomPresets(diverId: diverId);
      final builtInPresets = constants.TankPresets.all
          .map((p) => TankPresetEntity.fromBuiltIn(p))
          .toList();

      // Return custom first, then built-in
      return [...customPresets, ...builtInPresets];
    } catch (e, stackTrace) {
      _log.error('Failed to get all tank presets', e, stackTrace);
      rethrow;
    }
  }

  /// Get only custom (user-defined) tank presets for the specified diver
  Future<List<TankPresetEntity>> getCustomPresets({String? diverId}) async {
    try {
      // Custom presets require a diver
      if (diverId == null) {
        return [];
      }

      final query = _db.select(_db.tankPresets)
        ..where((t) => t.diverId.equals(diverId))
        ..orderBy([
          (t) => OrderingTerm.asc(t.sortOrder),
          (t) => OrderingTerm.asc(t.name),
        ]);

      final rows = await query.get();
      return rows.map(_mapRowToEntity).toList();
    } catch (e, stackTrace) {
      _log.error('Failed to get custom tank presets', e, stackTrace);
      rethrow;
    }
  }

  /// Get a single preset by ID (checks custom first, then built-in)
  Future<TankPresetEntity?> getPresetById(String id) async {
    try {
      // Check custom presets in DB first
      final query = _db.select(_db.tankPresets)..where((t) => t.id.equals(id));
      final row = await query.getSingleOrNull();
      if (row != null) {
        return _mapRowToEntity(row);
      }

      // Check built-in presets
      final builtIn = constants.TankPresets.byName(id);
      if (builtIn != null) {
        return TankPresetEntity.fromBuiltIn(builtIn);
      }

      return null;
    } catch (e, stackTrace) {
      _log.error('Failed to get tank preset by id: $id', e, stackTrace);
      rethrow;
    }
  }

  /// Get a preset by name (case-insensitive, checks custom then built-in)
  Future<TankPresetEntity?> getPresetByName(String name) async {
    try {
      // Check custom presets first
      final query = _db.select(_db.tankPresets)
        ..where((t) => t.name.lower().equals(name.toLowerCase()));
      final row = await query.getSingleOrNull();
      if (row != null) {
        return _mapRowToEntity(row);
      }

      // Check built-in presets
      final builtIn = constants.TankPresets.all.where(
        (p) => p.name.toLowerCase() == name.toLowerCase(),
      );
      if (builtIn.isNotEmpty) {
        return TankPresetEntity.fromBuiltIn(builtIn.first);
      }

      return null;
    } catch (e, stackTrace) {
      _log.error('Failed to get tank preset by name: $name', e, stackTrace);
      rethrow;
    }
  }

  /// Create a new custom tank preset
  Future<TankPresetEntity> createPreset(TankPresetEntity preset) async {
    try {
      // Custom presets must have a diver ID
      if (preset.diverId == null) {
        throw Exception(
          'Cannot create custom tank preset without a diver ID. '
          'Custom presets must be associated with a diver profile.',
        );
      }

      _log.info(
        'Creating tank preset: ${preset.displayName} for diver: ${preset.diverId}',
      );

      // Generate ID from name if empty
      final id = preset.id.isEmpty
          ? TankPresetEntity.generateSlug(preset.name)
          : preset.id;

      // Ensure the ID is unique
      final existing = await getPresetById(id);
      final uniqueId = existing != null
          ? '${id}_${_uuid.v4().substring(0, 8)}'
          : id;

      final now = DateTime.now().millisecondsSinceEpoch;

      // Get the next sort order
      final maxSortOrder = await _getMaxSortOrder(preset.diverId!);

      await _db
          .into(_db.tankPresets)
          .insert(
            TankPresetsCompanion(
              id: Value(uniqueId),
              diverId: Value(preset.diverId),
              name: Value(preset.name),
              displayName: Value(preset.displayName),
              volumeLiters: Value(preset.volumeLiters),
              workingPressureBar: Value(preset.workingPressureBar),
              material: Value(preset.material.name),
              description: Value(preset.description),
              sortOrder: Value(
                preset.sortOrder > 0 ? preset.sortOrder : maxSortOrder + 1,
              ),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await _syncRepository.markRecordPending(
        entityType: 'tankPresets',
        recordId: uniqueId,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();

      _log.info(
        'Created tank preset with id: $uniqueId for diver: ${preset.diverId}',
      );

      return preset.copyWith(
        id: uniqueId,
        sortOrder: preset.sortOrder > 0 ? preset.sortOrder : maxSortOrder + 1,
        createdAt: DateTime.fromMillisecondsSinceEpoch(now),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(now),
      );
    } catch (e, stackTrace) {
      _log.error('Failed to create tank preset', e, stackTrace);
      rethrow;
    }
  }

  /// Update an existing custom tank preset
  Future<void> updatePreset(TankPresetEntity preset) async {
    try {
      // Cannot update built-in presets
      if (preset.isBuiltIn) {
        throw Exception('Cannot update built-in tank presets');
      }

      _log.info('Updating tank preset: ${preset.id}');
      final now = DateTime.now().millisecondsSinceEpoch;

      await (_db.update(
        _db.tankPresets,
      )..where((t) => t.id.equals(preset.id))).write(
        TankPresetsCompanion(
          name: Value(preset.name),
          displayName: Value(preset.displayName),
          volumeLiters: Value(preset.volumeLiters),
          workingPressureBar: Value(preset.workingPressureBar),
          material: Value(preset.material.name),
          description: Value(preset.description),
          sortOrder: Value(preset.sortOrder),
          updatedAt: Value(now),
        ),
      );
      await _syncRepository.markRecordPending(
        entityType: 'tankPresets',
        recordId: preset.id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
      _log.info('Updated tank preset: ${preset.id}');
    } catch (e, stackTrace) {
      _log.error('Failed to update tank preset: ${preset.id}', e, stackTrace);
      rethrow;
    }
  }

  /// Delete a custom tank preset (built-in presets cannot be deleted)
  Future<void> deletePreset(String id) async {
    try {
      // Check if it's a built-in preset
      final builtIn = constants.TankPresets.byName(id);
      if (builtIn != null) {
        throw Exception('Cannot delete built-in tank presets');
      }

      _log.info('Deleting tank preset: $id');
      await (_db.delete(_db.tankPresets)..where((t) => t.id.equals(id))).go();
      await _syncRepository.logDeletion(
        entityType: 'tankPresets',
        recordId: id,
      );
      SyncEventBus.notifyLocalChange();
      _log.info('Deleted tank preset: $id');
    } catch (e, stackTrace) {
      _log.error('Failed to delete tank preset: $id', e, stackTrace);
      rethrow;
    }
  }

  // ============================================================================
  // Helpers
  // ============================================================================

  Future<int> _getMaxSortOrder(String diverId) async {
    final result = await _db
        .customSelect(
          '''
      SELECT MAX(sort_order) as max_order FROM tank_presets WHERE diver_id = ?
    ''',
          variables: [Variable.withString(diverId)],
        )
        .getSingleOrNull();
    return (result?.data['max_order'] as int?) ?? 0;
  }

  TankPresetEntity _mapRowToEntity(TankPreset row) {
    return TankPresetEntity(
      id: row.id,
      diverId: row.diverId,
      name: row.name,
      displayName: row.displayName,
      volumeLiters: row.volumeLiters,
      workingPressureBar: row.workingPressureBar,
      material: _parseMaterial(row.material),
      description: row.description,
      sortOrder: row.sortOrder,
      isBuiltIn: false, // Custom presets from DB are never built-in
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    );
  }

  TankMaterial _parseMaterial(String value) {
    return TankMaterial.values.firstWhere(
      (m) => m.name == value,
      orElse: () => TankMaterial.aluminum,
    );
  }
}
