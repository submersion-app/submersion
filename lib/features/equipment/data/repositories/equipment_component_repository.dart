import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/core/utils/stream_debounce.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

/// Thrown instead of writing a loop into the assembly graph.
class EquipmentComponentCycleException implements Exception {
  final String parentId;
  final String componentId;

  const EquipmentComponentCycleException(this.parentId, this.componentId);

  @override
  String toString() =>
      'Adding $componentId under $parentId would make the assembly graph '
      'cyclic';
}

/// The assembly template (issue #1487): which parts belong to which item.
///
/// Every write leaves sync bookkeeping behind (pending mark or tombstone) the
/// way EquipmentRepository.saveAttributes does, because the table is a
/// clocked child of equipment with its own hlc.
class EquipmentComponentRepository {
  EquipmentComponentRepository({EquipmentRepository? equipmentRepository})
    : _equipment = equipmentRepository ?? EquipmentRepository();

  final EquipmentRepository _equipment;
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(EquipmentComponentRepository);

  static const changeTickDebounce = Duration(milliseconds: 300);
  static const entityType = 'equipmentComponents';

  /// Emits on any write to the template or to the whole `equipment` table.
  /// A Drift table stream cannot be scoped to particular rows, so a hydrated
  /// read such as the Components card also refreshes on an unrelated gear
  /// edit; that read is one parent's parts, so the cost is small. Providers
  /// that hold only ids use [watchComponentEdgeChanges] instead.
  Stream<void> watchComponentChanges() => _db
      .tableUpdates(
        TableUpdateQuery.allOf([
          TableUpdateQuery.onTable(_db.equipmentComponents),
          TableUpdateQuery.onTable(_db.equipment),
        ]),
      )
      .debounce(changeTickDebounce);

  /// Emits only when the edges themselves change. The adjacency index reads
  /// ids alone, so a rename of a part must not make it re-read every row.
  Stream<void> watchComponentEdgeChanges() => _db
      .tableUpdates(TableUpdateQuery.onTable(_db.equipmentComponents))
      .debounce(changeTickDebounce);

  EquipmentComponent _map(
    EquipmentComponentRow row, {
    EquipmentItem? component,
  }) => EquipmentComponent(
    id: row.id,
    parentEquipmentId: row.parentEquipmentId,
    componentEquipmentId: row.componentEquipmentId,
    role: row.role,
    sortOrder: row.sortOrder,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    component: component,
  );

  /// Every row, unhydrated, ordered by parent then position, with the row
  /// id as the final key so two parts that collide on sort_order (a sync
  /// merge of concurrent reorders) still come back in one fixed order. The
  /// adjacency index is built from this in one read.
  Future<List<EquipmentComponent>> getAllComponents() async {
    final rows =
        await (_db.select(_db.equipmentComponents)..orderBy([
              (t) => OrderingTerm.asc(t.parentEquipmentId),
              (t) => OrderingTerm.asc(t.sortOrder),
              (t) => OrderingTerm.asc(t.id),
            ]))
            .get();
    return rows.map(_map).toList();
  }

  /// The parts of [parentId] with their items hydrated, in sort order, the
  /// row id breaking ties so a sort_order collision cannot reshuffle rows
  /// between reads.
  Future<List<EquipmentComponent>> getComponents(String parentId) async {
    final rows =
        await (_db.select(_db.equipmentComponents)
              ..where((t) => t.parentEquipmentId.equals(parentId))
              ..orderBy([
                (t) => OrderingTerm.asc(t.sortOrder),
                (t) => OrderingTerm.asc(t.id),
              ]))
            .get();
    if (rows.isEmpty) return const [];
    final items = await _equipment.getEquipmentByIds(
      rows.map((r) => r.componentEquipmentId).toList(),
    );
    final byId = {for (final i in items) i.id: i};
    return [
      for (final r in rows) _map(r, component: byId[r.componentEquipmentId]),
    ];
  }

  /// Ids reachable upward from [id]: its parents, their parents, and so on.
  ///
  /// Walks one frontier at a time, querying only the rows whose part is in
  /// that frontier, so the cost follows the edges actually reachable rather
  /// than the whole table. A visited set makes the walk terminate even on a
  /// corrupt graph.
  Future<Set<String>> ancestorsOf(String id) async {
    final seen = <String>{};
    var frontier = <String>{id};
    while (frontier.isNotEmpty) {
      final rows = await (_db.select(
        _db.equipmentComponents,
      )..where((t) => t.componentEquipmentId.isIn(frontier.toList()))).get();
      frontier = {
        for (final r in rows)
          if (seen.add(r.parentEquipmentId)) r.parentEquipmentId,
      };
    }
    return seen;
  }

  /// True when [componentId] is [parentId] itself or one of its ancestors:
  /// linking it underneath would close a loop.
  Future<bool> wouldCreateCycle({
    required String parentId,
    required String componentId,
  }) async {
    if (parentId == componentId) return true;
    return (await ancestorsOf(parentId)).contains(componentId);
  }

  /// Appends [componentId] under [parentId]. Throws
  /// [EquipmentComponentCycleException] rather than writing a loop; adding
  /// a pair that already exists returns the existing row unchanged.
  Future<EquipmentComponent> addComponent({
    required String parentId,
    required String componentId,
    String role = '',
  }) async {
    if (await wouldCreateCycle(parentId: parentId, componentId: componentId)) {
      throw EquipmentComponentCycleException(parentId, componentId);
    }
    final existing =
        await (_db.select(_db.equipmentComponents)..where(
              (t) =>
                  t.parentEquipmentId.equals(parentId) &
                  t.componentEquipmentId.equals(componentId),
            ))
            .getSingleOrNull();
    if (existing != null) return _map(existing);

    final siblings = await (_db.select(
      _db.equipmentComponents,
    )..where((t) => t.parentEquipmentId.equals(parentId))).get();
    final nextOrder = siblings.isEmpty
        ? 0
        : siblings.map((s) => s.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = _uuid.v4();
    await _db
        .into(_db.equipmentComponents)
        .insert(
          EquipmentComponentsCompanion(
            id: Value(id),
            parentEquipmentId: Value(parentId),
            componentEquipmentId: Value(componentId),
            role: Value(role.trim()),
            sortOrder: Value(nextOrder),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    await _syncRepository.markRecordPending(
      entityType: entityType,
      recordId: id,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
    _log.info('Added component $componentId under $parentId');
    final row = await (_db.select(
      _db.equipmentComponents,
    )..where((t) => t.id.equals(id))).getSingle();
    return _map(row);
  }

  Future<void> updateRole(String id, String role) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(
      _db.equipmentComponents,
    )..where((t) => t.id.equals(id))).write(
      EquipmentComponentsCompanion(
        role: Value(role.trim()),
        updatedAt: Value(now),
      ),
    );
    await _syncRepository.markRecordPending(
      entityType: entityType,
      recordId: id,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }

  /// Rewrites sort_order so [orderedIds] (component row ids under
  /// [parentId]) run 0..n-1 in the given sequence.
  Future<void> reorder(String parentId, List<String> orderedIds) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction(() async {
      for (final (index, id) in orderedIds.indexed) {
        await (_db.update(_db.equipmentComponents)..where(
              (t) => t.id.equals(id) & t.parentEquipmentId.equals(parentId),
            ))
            .write(
              EquipmentComponentsCompanion(
                sortOrder: Value(index),
                updatedAt: Value(now),
              ),
            );
      }
    });
    for (final id in orderedIds) {
      await _syncRepository.markRecordPending(
        entityType: entityType,
        recordId: id,
        localUpdatedAt: now,
      );
    }
    SyncEventBus.notifyLocalChange();
  }

  Future<void> removeComponent(String id) async {
    await (_db.delete(
      _db.equipmentComponents,
    )..where((t) => t.id.equals(id))).go();
    await _syncRepository.logDeletion(entityType: entityType, recordId: id);
    SyncEventBus.notifyLocalChange();
    _log.info('Removed component row $id');
  }

  /// Roles already in use, each once, sorted, blanks dropped. Feeds the
  /// role dialog's suggestion chips.
  Future<List<String>> distinctRoles() async {
    final rows = await _db.select(_db.equipmentComponents).get();
    final roles = {
      for (final r in rows)
        if (r.role.isNotEmpty) r.role,
    };
    return roles.toList()..sort();
  }
}
