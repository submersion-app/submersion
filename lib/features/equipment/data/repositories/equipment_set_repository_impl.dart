import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/core/utils/stream_debounce.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart'
    as domain;
import 'package:submersion/features/equipment/domain/entities/equipment_set_geofence.dart'
    as domain;
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';

class EquipmentSetRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();
  final _equipmentRepo = EquipmentRepository();
  final _log = LoggerService.forClass(EquipmentSetRepository);

  /// Debounce for [watchSetChanges] so a multi-changeset sync refreshes the
  /// set surfaces once on the settled DB state instead of once per commit
  /// (mirrors DiveRepository.changeTickDebounce).
  static const changeTickDebounce = Duration(milliseconds: 300);

  /// Emits whenever anything an equipment set renders changes, so the
  /// set providers can self-invalidate after ANY write -- including a sync or
  /// an import applying changes straight to the DB, which bypasses the
  /// notifier paths that invalidate caches on local edits.
  ///
  /// Watches the hydration sources, not just `equipment_sets`:
  /// - `equipment_set_items` -- membership. This is also the target of drift's
  ///   generated `WritePropagation` for the `equipment` ON DELETE CASCADE, so
  ///   deleting a gear item ticks here even though the DELETE statement only
  ///   named `equipment` (see `streamUpdateRules` in database.g.dart).
  /// - `equipment` -- [getSetById] with `includeItems` hydrates full items, and
  ///   the cascade propagation above is delete-only, so a RENAME of a member
  ///   only surfaces if this table is watched directly.
  /// - `equipment_set_geofences` -- hydrated by the set detail/edit providers.
  ///
  /// Without this, deleting a gear item left every cached set carrying the dead
  /// id; the edit form then re-inserted it and the save died on the FK
  /// (issue #819).
  Stream<void> watchSetChanges() => _db
      .tableUpdates(
        TableUpdateQuery.allOf([
          TableUpdateQuery.onTable(_db.equipmentSets),
          TableUpdateQuery.onTable(_db.equipmentSetItems),
          TableUpdateQuery.onTable(_db.equipment),
          TableUpdateQuery.onTable(_db.equipmentSetGeofences),
        ]),
      )
      .debounce(changeTickDebounce);

  /// The subset of [ids] that still has an `equipment` row, preserving order.
  ///
  /// A caller can legitimately hold ids that no longer exist: SQLite cascades
  /// the junction rows away the instant a gear item is deleted, but an
  /// in-memory equipment set -- or an edit form already on screen -- keeps its
  /// snapshot of the membership. Inserting such an id fails the
  /// foreign key and aborts the entire save (issue #819), so drop it instead.
  ///
  /// Deliberately NOT `InsertMode.insertOrIgnore`: this is a foreign-key
  /// violation rather than a uniqueness conflict, and ignoring it would hide
  /// the drop entirely. The set is the diver's data and must still save, but a
  /// silent prune would also mask a genuine provider-staleness regression --
  /// hence the warning.
  Future<List<String>> _liveEquipmentIds(String setId, List<String> ids) async {
    if (ids.isEmpty) return const [];
    final rows = await (_db.select(
      _db.equipment,
    )..where((t) => t.id.isIn(ids))).get();
    final live = rows.map((r) => r.id).toSet();
    final kept = ids.where(live.contains).toList();
    if (kept.length != ids.length) {
      final missing = ids.where((id) => !live.contains(id));
      _log.warning(
        'Equipment set $setId: dropping ${ids.length - kept.length} member(s) '
        'whose equipment no longer exists (${missing.join(', ')})',
      );
    }
    return kept;
  }

  /// Get all equipment sets
  Future<List<domain.EquipmentSet>> getAllSets({String? diverId}) async {
    final query = _db.select(_db.equipmentSets)
      ..orderBy([(t) => OrderingTerm.asc(t.name)]);

    if (diverId != null) {
      query.where((t) => t.diverId.equals(diverId));
    }

    final rows = await query.get();

    final sets = <domain.EquipmentSet>[];
    for (final row in rows) {
      final equipmentIds = await getEquipmentIdsInSet(row.id);
      sets.add(_mapRowToSet(row, equipmentIds));
    }
    return sets;
  }

  /// Get set by ID
  Future<domain.EquipmentSet?> getSetById(
    String id, {
    bool includeItems = false,
    bool includeGeofences = false,
  }) async {
    final query = _db.select(_db.equipmentSets)..where((t) => t.id.equals(id));
    final row = await query.getSingleOrNull();
    if (row == null) return null;

    final equipmentIds = await getEquipmentIdsInSet(id);
    var set = _mapRowToSet(row, equipmentIds);

    if (includeItems) {
      final items = await _equipmentRepo.getEquipmentByIds(equipmentIds);
      set = set.copyWith(items: items);
    }
    if (includeGeofences) {
      set = set.copyWith(geofences: await getGeofencesForSet(id));
    }
    return set;
  }

  /// Get equipment IDs in a set
  Future<List<String>> getEquipmentIdsInSet(String setId) async {
    final query = _db.select(_db.equipmentSetItems)
      ..where((t) => t.setId.equals(setId));
    final rows = await query.get();
    return rows.map((r) => r.equipmentId).toList();
  }

  /// Create a new equipment set.
  ///
  /// The set row and its membership are one logical write, so they share a
  /// transaction: a failing member insert must not leave a named set behind
  /// with a partial roster. Sync bookkeeping runs after the commit so a
  /// rollback leaves no stray pending markers (mirrors DivePlanRepository).
  Future<domain.EquipmentSet> createSet(domain.EquipmentSet set) async {
    final id = set.id.isEmpty ? _uuid.v4() : set.id;
    final now = DateTime.now().millisecondsSinceEpoch;
    late final List<String> members;

    await _db.transaction(() async {
      await _db
          .into(_db.equipmentSets)
          .insert(
            EquipmentSetsCompanion(
              id: Value(id),
              diverId: Value(set.diverId),
              name: Value(set.name),
              description: Value(set.description),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      members = await _liveEquipmentIds(id, set.equipmentIds);
      for (final equipmentId in members) {
        await _db
            .into(_db.equipmentSetItems)
            .insert(
              EquipmentSetItemsCompanion(
                setId: Value(id),
                equipmentId: Value(equipmentId),
              ),
            );
      }
    });

    await _syncRepository.markRecordPending(
      entityType: 'equipmentSets',
      recordId: id,
      localUpdatedAt: now,
    );
    for (final equipmentId in members) {
      await _syncRepository.markRecordPending(
        entityType: 'equipmentSetItems',
        recordId: '$id|$equipmentId',
        localUpdatedAt: now,
      );
    }
    SyncEventBus.notifyLocalChange();

    return set.copyWith(
      id: id,
      equipmentIds: members,
      createdAt: DateTime.fromMillisecondsSinceEpoch(now),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(now),
    );
  }

  /// Update an equipment set.
  ///
  /// Membership is reconciled as a DIFF rather than delete-all-then-reinsert.
  /// The old shape had two defects this flow hits hard: it was untransacted, so
  /// a failing re-insert left the set empty with every member already
  /// tombstoned (issue #819); and it tombstoned + re-marked every member on
  /// every save even when nothing changed, which is the churn the
  /// contradicted-key handling in SyncService exists to absorb. Diffing removes
  /// both. Mirrors the composite-PK junction handling in
  /// DivePlanRepository.updatePlan, including running sync bookkeeping only
  /// after the transaction commits.
  Future<void> updateSet(domain.EquipmentSet set) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final added = <String>[];
    final removed = <String>[];

    await _db.transaction(() async {
      await (_db.update(
        _db.equipmentSets,
      )..where((t) => t.id.equals(set.id))).write(
        EquipmentSetsCompanion(
          name: Value(set.name),
          description: Value(set.description),
          updatedAt: Value(now),
        ),
      );

      final desired = (await _liveEquipmentIds(
        set.id,
        set.equipmentIds,
      )).toSet();
      final existing =
          (await (_db.select(
                _db.equipmentSetItems,
              )..where((t) => t.setId.equals(set.id))).get())
              .map((r) => r.equipmentId)
              .toSet();

      added.addAll(desired.difference(existing));
      removed.addAll(existing.difference(desired));

      for (final equipmentId in added) {
        await _db
            .into(_db.equipmentSetItems)
            .insert(
              EquipmentSetItemsCompanion(
                setId: Value(set.id),
                equipmentId: Value(equipmentId),
              ),
              mode: InsertMode.insertOrIgnore,
            );
      }
      for (final equipmentId in removed) {
        await (_db.delete(_db.equipmentSetItems)..where(
              (t) => t.setId.equals(set.id) & t.equipmentId.equals(equipmentId),
            ))
            .go();
      }
    });

    await _syncRepository.markRecordPending(
      entityType: 'equipmentSets',
      recordId: set.id,
      localUpdatedAt: now,
    );
    for (final equipmentId in added) {
      await _syncRepository.markRecordPending(
        entityType: 'equipmentSetItems',
        recordId: '${set.id}|$equipmentId',
        localUpdatedAt: now,
      );
    }
    for (final equipmentId in removed) {
      await _syncRepository.logDeletion(
        entityType: 'equipmentSetItems',
        recordId: '${set.id}|$equipmentId',
      );
    }
    SyncEventBus.notifyLocalChange();
  }

  /// Delete an equipment set.
  ///
  /// Geofences are a first-class synced child cascade-deleted by SQLite, but
  /// cascades emit no deletion-log entries, so each geofence must be tombstoned
  /// explicitly or a peer will resurrect it. Done in one transaction with the
  /// set deletion (mirrors the buddy/certification deletion path).
  Future<void> deleteSet(String id) async {
    await _db.transaction(() async {
      final geofences = await getGeofencesForSet(id);
      await (_db.delete(_db.equipmentSets)..where((t) => t.id.equals(id))).go();
      for (final g in geofences) {
        await _syncRepository.logDeletion(
          entityType: 'equipmentSetGeofences',
          recordId: g.id,
        );
      }
      await _syncRepository.logDeletion(
        entityType: 'equipmentSets',
        recordId: id,
      );
    });
    SyncEventBus.notifyLocalChange();
  }

  /// Add equipment item to set
  Future<void> addItemToSet(String setId, String equipmentId) async {
    await _db
        .into(_db.equipmentSetItems)
        .insert(
          EquipmentSetItemsCompanion(
            setId: Value(setId),
            equipmentId: Value(equipmentId),
          ),
        );
    // Update the set's updatedAt timestamp
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.equipmentSets)..where((t) => t.id.equals(setId)))
        .write(EquipmentSetsCompanion(updatedAt: Value(now)));
    await _syncRepository.markRecordPending(
      entityType: 'equipmentSetItems',
      recordId: '$setId|$equipmentId',
      localUpdatedAt: now,
    );
    await _syncRepository.markRecordPending(
      entityType: 'equipmentSets',
      recordId: setId,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }

  /// Remove equipment item from set
  Future<void> removeItemFromSet(String setId, String equipmentId) async {
    final existing =
        await (_db.select(_db.equipmentSetItems)..where(
              (t) => t.setId.equals(setId) & t.equipmentId.equals(equipmentId),
            ))
            .get();
    await (_db.delete(_db.equipmentSetItems)..where(
          (t) => t.setId.equals(setId) & t.equipmentId.equals(equipmentId),
        ))
        .go();
    // Update the set's updatedAt timestamp
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.equipmentSets)..where((t) => t.id.equals(setId)))
        .write(EquipmentSetsCompanion(updatedAt: Value(now)));
    for (final item in existing) {
      await _syncRepository.logDeletion(
        entityType: 'equipmentSetItems',
        recordId: '${item.setId}|${item.equipmentId}',
      );
    }
    await _syncRepository.markRecordPending(
      entityType: 'equipmentSets',
      recordId: setId,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }

  /// Set [id] as the diver's default equipment set, clearing the flag from the
  /// diver's other sets. The scope is derived from the target set's own owner
  /// so the clear/promote/mark-pending steps always cover the same diver, even
  /// if a caller passes a mismatched [diverId] (the parameter is retained for
  /// API compatibility but the target row is authoritative). Runs in a single
  /// transaction so a partial write cannot leave two defaults.
  Future<void> setAsDefault(String id, {String? diverId}) async {
    await _db.transaction(() async {
      final now = DateTime.now().millisecondsSinceEpoch;

      final target = await (_db.select(
        _db.equipmentSets,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (target == null) return;
      final ownerId = target.diverId;

      await (_db.update(_db.equipmentSets)..where(
            (t) => ownerId == null
                ? t.diverId.isNull()
                : t.diverId.equals(ownerId),
          ))
          .write(
            EquipmentSetsCompanion(
              isDefault: const Value(false),
              updatedAt: Value(now),
            ),
          );

      await (_db.update(
        _db.equipmentSets,
      )..where((t) => t.id.equals(id))).write(
        EquipmentSetsCompanion(
          isDefault: const Value(true),
          updatedAt: Value(now),
        ),
      );

      // The promoted row is in scope by construction (its owner defines the
      // scope), so this sweep marks it and every demoted sibling pending.
      final affected =
          await (_db.select(_db.equipmentSets)..where(
                (t) => ownerId == null
                    ? t.diverId.isNull()
                    : t.diverId.equals(ownerId),
              ))
              .get();
      for (final row in affected) {
        await _syncRepository.markRecordPending(
          entityType: 'equipmentSets',
          recordId: row.id,
          localUpdatedAt: now,
        );
      }
    });
    SyncEventBus.notifyLocalChange();
  }

  /// Clear the default flag from a single set, leaving the diver with no
  /// default (nothing auto-applies until a default is set again).
  Future<void> clearDefault(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.equipmentSets)..where((t) => t.id.equals(id))).write(
      EquipmentSetsCompanion(
        isDefault: const Value(false),
        updatedAt: Value(now),
      ),
    );
    await _syncRepository.markRecordPending(
      entityType: 'equipmentSets',
      recordId: id,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }

  /// All geofences for a set.
  Future<List<domain.EquipmentSetGeofence>> getGeofencesForSet(
    String setId,
  ) async {
    final rows = await (_db.select(
      _db.equipmentSetGeofences,
    )..where((t) => t.setId.equals(setId))).get();
    return rows.map(_mapRowToGeofence).toList();
  }

  /// All geofences belonging to the given diver's sets (or all sets when
  /// [diverId] is null).
  Future<List<domain.EquipmentSetGeofence>> getAllGeofences({
    String? diverId,
  }) async {
    final setQuery = _db.select(_db.equipmentSets);
    if (diverId != null) {
      setQuery.where((t) => t.diverId.equals(diverId));
    }
    final setIds = (await setQuery.get()).map((s) => s.id).toSet();
    if (setIds.isEmpty) return [];
    final rows = await (_db.select(
      _db.equipmentSetGeofences,
    )..where((t) => t.setId.isIn(setIds))).get();
    return rows.map(_mapRowToGeofence).toList();
  }

  Future<void> addGeofence(domain.EquipmentSetGeofence fence) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db
        .into(_db.equipmentSetGeofences)
        .insert(
          EquipmentSetGeofencesCompanion(
            id: Value(fence.id),
            setId: Value(fence.setId),
            label: Value(fence.label),
            latitude: Value(fence.latitude),
            longitude: Value(fence.longitude),
            radiusMeters: Value(fence.radiusMeters),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    await _syncRepository.markRecordPending(
      entityType: 'equipmentSetGeofences',
      recordId: fence.id,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }

  Future<void> updateGeofence(domain.EquipmentSetGeofence fence) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(
      _db.equipmentSetGeofences,
    )..where((t) => t.id.equals(fence.id))).write(
      EquipmentSetGeofencesCompanion(
        label: Value(fence.label),
        latitude: Value(fence.latitude),
        longitude: Value(fence.longitude),
        radiusMeters: Value(fence.radiusMeters),
        updatedAt: Value(now),
      ),
    );
    await _syncRepository.markRecordPending(
      entityType: 'equipmentSetGeofences',
      recordId: fence.id,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }

  Future<void> removeGeofence(String geofenceId) async {
    await (_db.delete(
      _db.equipmentSetGeofences,
    )..where((t) => t.id.equals(geofenceId))).go();
    await _syncRepository.logDeletion(
      entityType: 'equipmentSetGeofences',
      recordId: geofenceId,
    );
    SyncEventBus.notifyLocalChange();
  }

  domain.EquipmentSetGeofence _mapRowToGeofence(EquipmentSetGeofence row) {
    return domain.EquipmentSetGeofence(
      id: row.id,
      setId: row.setId,
      label: row.label,
      latitude: row.latitude,
      longitude: row.longitude,
      radiusMeters: row.radiusMeters,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    );
  }

  domain.EquipmentSet _mapRowToSet(
    EquipmentSet row,
    List<String> equipmentIds,
  ) {
    return domain.EquipmentSet(
      id: row.id,
      diverId: row.diverId,
      name: row.name,
      description: row.description,
      equipmentIds: equipmentIds,
      isDefault: row.isDefault,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    );
  }
}
