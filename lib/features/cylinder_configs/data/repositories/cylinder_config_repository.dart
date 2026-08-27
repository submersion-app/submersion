import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config.dart'
    as domain;
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config_item.dart'
    as domain;

/// Persistence for reusable cylinder configurations.
///
/// Modelled on EquipmentSetRepository: writes register sync intent through
/// SyncRepository and notify the event bus, and child deletes always write a
/// deletion-log tombstone (a child removed without one resurrects on the next
/// sync pull).
class CylinderConfigRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();

  /// Emits whenever a cylinder configuration or one of its items changes, so
  /// the config providers refresh after a sync or any other write that
  /// bypasses the notifiers. Watches the item table too, because a config is
  /// only meaningful with its items and a sync can apply either independently.
  Stream<void> watchConfigsChanges() => _db.tableUpdates(
    TableUpdateQuery.allOf([
      TableUpdateQuery.onTable(_db.cylinderConfigs),
      TableUpdateQuery.onTable(_db.cylinderConfigItems),
    ]),
  );

  static const String _configEntity = 'cylinderConfigs';
  static const String _itemEntity = 'cylinderConfigItems';

  /// Unknown persisted values degrade to a sensible default rather than
  /// throwing: a row written by a newer version must not break an older one.
  TankRole _roleFrom(String value) => TankRole.values.firstWhere(
    (r) => r.name == value,
    orElse: () => TankRole.backGas,
  );

  TankMaterial? _materialFrom(String? value) {
    if (value == null) return null;
    for (final material in TankMaterial.values) {
      if (material.name == value) return material;
    }
    return null;
  }

  domain.CylinderConfig _mapConfig(
    CylinderConfig row,
    List<domain.CylinderConfigItem> items,
  ) => domain.CylinderConfig(
    id: row.id,
    diverId: row.diverId,
    equipmentId: row.equipmentId,
    name: row.name,
    description: row.description,
    sortOrder: row.sortOrder,
    items: items,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
  );

  domain.CylinderConfigItem _mapItem(CylinderConfigItem row) =>
      domain.CylinderConfigItem(
        id: row.id,
        configId: row.configId,
        sortOrder: row.sortOrder,
        label: row.label,
        tankRole: _roleFrom(row.tankRole),
        volumeL: row.volumeL,
        workingPressureBar: row.workingPressureBar,
        tankMaterial: _materialFrom(row.tankMaterial),
        o2Percent: row.o2Percent,
        hePercent: row.hePercent,
        defaultStartPressureBar: row.defaultStartPressureBar,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
      );

  Future<List<domain.CylinderConfigItem>> _itemsFor(String configId) async {
    final rows =
        await (_db.select(_db.cylinderConfigItems)
              ..where((t) => t.configId.equals(configId))
              ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
            .get();
    return rows.map(_mapItem).toList();
  }

  Future<List<domain.CylinderConfig>> getAllConfigs({
    String? diverId,
    bool includeItems = false,
  }) async {
    final query = _db.select(_db.cylinderConfigs)
      ..orderBy([
        (t) => OrderingTerm.asc(t.sortOrder),
        (t) => OrderingTerm.asc(t.name),
      ]);
    if (diverId != null) {
      query.where((t) => t.diverId.equals(diverId));
    }

    final rows = await query.get();
    final configs = <domain.CylinderConfig>[];
    for (final row in rows) {
      configs.add(
        _mapConfig(row, includeItems ? await _itemsFor(row.id) : const []),
      );
    }
    return configs;
  }

  Future<List<domain.CylinderConfig>> getConfigsForEquipment(
    String equipmentId,
  ) async {
    final rows =
        await (_db.select(_db.cylinderConfigs)
              ..where((t) => t.equipmentId.equals(equipmentId))
              ..orderBy([
                (t) => OrderingTerm.asc(t.sortOrder),
                (t) => OrderingTerm.asc(t.name),
              ]))
            .get();
    final configs = <domain.CylinderConfig>[];
    for (final row in rows) {
      configs.add(_mapConfig(row, await _itemsFor(row.id)));
    }
    return configs;
  }

  Future<domain.CylinderConfig?> getConfigById(
    String id, {
    bool includeItems = true,
  }) async {
    final row = await (_db.select(
      _db.cylinderConfigs,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    return _mapConfig(row, includeItems ? await _itemsFor(id) : const []);
  }

  Future<String> createConfig({
    String? diverId,
    String? equipmentId,
    required String name,
    String description = '',
    int sortOrder = 0,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    await _db
        .into(_db.cylinderConfigs)
        .insert(
          CylinderConfigsCompanion.insert(
            id: id,
            diverId: Value(diverId),
            equipmentId: Value(equipmentId),
            name: name,
            description: Value(description),
            sortOrder: Value(sortOrder),
            createdAt: now,
            updatedAt: now,
          ),
        );

    await _syncRepository.markRecordPending(
      entityType: _configEntity,
      recordId: id,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
    return id;
  }

  Future<void> updateConfig(domain.CylinderConfig config) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await (_db.update(
      _db.cylinderConfigs,
    )..where((t) => t.id.equals(config.id))).write(
      CylinderConfigsCompanion(
        diverId: Value(config.diverId),
        equipmentId: Value(config.equipmentId),
        name: Value(config.name),
        description: Value(config.description),
        sortOrder: Value(config.sortOrder),
        updatedAt: Value(now),
      ),
    );

    await _syncRepository.markRecordPending(
      entityType: _configEntity,
      recordId: config.id,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }

  /// Deletes a config and its items. The database cascades the children, but
  /// each one still needs its own tombstone: a peer that has not seen the
  /// delete would otherwise push the child straight back.
  Future<void> deleteConfig(String id) async {
    final itemIds = (await (_db.select(
      _db.cylinderConfigItems,
    )..where((t) => t.configId.equals(id))).get()).map((r) => r.id).toList();

    await _db.transaction(() async {
      await (_db.delete(
        _db.cylinderConfigs,
      )..where((t) => t.id.equals(id))).go();

      for (final itemId in itemIds) {
        await _syncRepository.logDeletion(
          entityType: _itemEntity,
          recordId: itemId,
        );
      }
      await _syncRepository.logDeletion(
        entityType: _configEntity,
        recordId: id,
      );
    });

    SyncEventBus.notifyLocalChange();
  }

  /// Writes the desired end state of [configId]'s cylinders: inserts and
  /// updates rows present in [desired], deletes (with a tombstone) any row no
  /// longer listed. sortOrder is renumbered from list position so the caller
  /// can reorder by moving list entries without maintaining indices.
  Future<void> saveItems(
    String configId,
    List<domain.CylinderConfigItem> desired,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    final existingRows = await (_db.select(
      _db.cylinderConfigItems,
    )..where((t) => t.configId.equals(configId))).get();
    final existingById = {for (final row in existingRows) row.id: row};

    final normalized = <domain.CylinderConfigItem>[];
    for (var index = 0; index < desired.length; index++) {
      final item = desired[index];
      normalized.add(
        item.copyWith(
          id: item.id.isNotEmpty ? item.id : _uuid.v4(),
          configId: configId,
          sortOrder: index,
        ),
      );
    }
    final desiredIds = normalized.map((i) => i.id).toSet();
    final pendingIds = <String>[];

    await _db.transaction(() async {
      for (final row in existingRows) {
        if (desiredIds.contains(row.id)) continue;
        await (_db.delete(
          _db.cylinderConfigItems,
        )..where((t) => t.id.equals(row.id))).go();
        await _syncRepository.logDeletion(
          entityType: _itemEntity,
          recordId: row.id,
        );
      }

      for (final item in normalized) {
        final existing = existingById[item.id];
        await _db
            .into(_db.cylinderConfigItems)
            .insertOnConflictUpdate(
              CylinderConfigItemsCompanion(
                id: Value(item.id),
                configId: Value(configId),
                sortOrder: Value(item.sortOrder),
                label: Value(item.label),
                tankRole: Value(item.tankRole.name),
                volumeL: Value(item.volumeL),
                workingPressureBar: Value(item.workingPressureBar),
                tankMaterial: Value(item.tankMaterial?.name),
                o2Percent: Value(item.o2Percent),
                hePercent: Value(item.hePercent),
                defaultStartPressureBar: Value(item.defaultStartPressureBar),
                createdAt: Value(existing?.createdAt ?? now),
                updatedAt: Value(now),
              ),
            );
        pendingIds.add(item.id);
      }
    });

    for (final id in pendingIds) {
      await _syncRepository.markRecordPending(
        entityType: _itemEntity,
        recordId: id,
        localUpdatedAt: now,
      );
    }
    SyncEventBus.notifyLocalChange();
  }
}
