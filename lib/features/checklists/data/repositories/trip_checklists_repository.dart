import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist.dart'
    as domain;

/// CRUD for a trip's checklists (issue #3356): the entity between a trip and
/// its [TripChecklistSection]/[TripChecklistItem] rows, introduced so one
/// trip can carry several independently named, independently tracked lists
/// ("Dive equipment", "Clothing", "Beach vacation") instead of one flat one.
class TripChecklistsRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();

  Stream<void> watchTripChecklistsChanges() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.tripChecklists));

  Future<List<domain.TripChecklist>> getChecklistsForTrip(String tripId) async {
    final rows =
        await (_db.select(_db.tripChecklists)
              ..where((c) => c.tripId.equals(tripId))
              ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
            .get();
    return rows.map(_mapRow).toList();
  }

  /// Creates a checklist at the end of the trip's checklist order.
  Future<domain.TripChecklist> createChecklist({
    required String tripId,
    required String name,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    final sortOrder = await _nextSortOrder(tripId);
    await _db
        .into(_db.tripChecklists)
        .insert(
          TripChecklistsCompanion(
            id: Value(id),
            tripId: Value(tripId),
            name: Value(name),
            sortOrder: Value(sortOrder),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    await _syncRepository.markRecordPending(
      entityType: 'tripChecklists',
      recordId: id,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
    return domain.TripChecklist(
      id: id,
      tripId: tripId,
      name: name,
      sortOrder: sortOrder,
      createdAt: DateTime.fromMillisecondsSinceEpoch(now),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(now),
    );
  }

  Future<void> renameChecklist(String id, String name) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.tripChecklists)..where((c) => c.id.equals(id))).write(
      TripChecklistsCompanion(name: Value(name), updatedAt: Value(now)),
    );
    await _syncRepository.markRecordPending(
      entityType: 'tripChecklists',
      recordId: id,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }

  /// Persists a new checklist order. [orderedIds] must list every checklist
  /// of the trip exactly once; sort order is the list position.
  Future<void> reorderChecklists(String tripId, List<String> orderedIds) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final changedIds = await _db.transaction(() async {
      final sortOrderById = {
        for (final c in await getChecklistsForTrip(tripId)) c.id: c.sortOrder,
      };
      final changed = <String>[];
      for (var i = 0; i < orderedIds.length; i++) {
        final current = sortOrderById[orderedIds[i]];
        if (current == null || current == i) continue;
        await (_db.update(_db.tripChecklists)..where(
              (c) => c.id.equals(orderedIds[i]) & c.tripId.equals(tripId),
            ))
            .write(
              TripChecklistsCompanion(
                sortOrder: Value(i),
                updatedAt: Value(now),
              ),
            );
        changed.add(orderedIds[i]);
      }
      return changed;
    });
    if (changedIds.isEmpty) return;
    for (final id in changedIds) {
      await _syncRepository.markRecordPending(
        entityType: 'tripChecklists',
        recordId: id,
        localUpdatedAt: now,
      );
    }
    SyncEventBus.notifyLocalChange();
  }

  /// Deletes a checklist and everything in it: its items, then its
  /// sections, then the checklist row itself. No SQL `ON DELETE` action
  /// exists for `checklist_id` (matching every other FK in this table
  /// family), so the cascade is explicit here, in the same order
  /// [deleteAllForTrip] and `TripChecklistSectionRepository.deleteSection`
  /// already use for items.
  Future<void> deleteChecklist(String id) async {
    final (itemIds, sectionIds) = await _db.transaction(() async {
      final items = await (_db.select(
        _db.tripChecklistItems,
      )..where((t) => t.checklistId.equals(id))).get();
      final sections = await (_db.select(
        _db.tripChecklistSections,
      )..where((s) => s.checklistId.equals(id))).get();
      await (_db.delete(
        _db.tripChecklistItems,
      )..where((t) => t.checklistId.equals(id))).go();
      await (_db.delete(
        _db.tripChecklistSections,
      )..where((s) => s.checklistId.equals(id))).go();
      await (_db.delete(
        _db.tripChecklists,
      )..where((c) => c.id.equals(id))).go();
      return (
        items.map((i) => i.id).toList(),
        sections.map((s) => s.id).toList(),
      );
    });
    await _syncRepository.logDeletions(
      entityType: 'tripChecklistItems',
      recordIds: itemIds,
    );
    await _syncRepository.logDeletions(
      entityType: 'tripChecklistSections',
      recordIds: sectionIds,
    );
    await _syncRepository.logDeletion(
      entityType: 'tripChecklists',
      recordId: id,
    );
    SyncEventBus.notifyLocalChange();
  }

  /// Bulk cascade used by `TripRepository.deleteTrip`: deletes every
  /// checklist of [tripId] (and, through [deleteChecklist], their sections
  /// and items). Also covers diver delete, which deletes a diver's trips
  /// through the same `deleteTrip` path rather than a separate ownership
  /// sweep.
  Future<void> deleteAllForTrip(String tripId) async {
    final checklists = await getChecklistsForTrip(tripId);
    for (final checklist in checklists) {
      await deleteChecklist(checklist.id);
    }
  }

  Future<int> _nextSortOrder(String tripId) async {
    final row = await _db
        .customSelect(
          'SELECT COALESCE(MAX(sort_order), -1) + 1 AS next '
          'FROM trip_checklists WHERE trip_id = ?',
          variables: [Variable.withString(tripId)],
        )
        .getSingle();
    return row.read<int>('next');
  }

  domain.TripChecklist _mapRow(TripChecklistRow row) => domain.TripChecklist(
    id: row.id,
    tripId: row.tripId,
    name: row.name,
    sortOrder: row.sortOrder,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
  );
}
