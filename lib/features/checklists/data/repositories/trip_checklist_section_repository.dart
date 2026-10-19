import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart' hide Trip;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist_section.dart'
    as domain;

/// Section CRUD for trip checklists (issue #3360), split out of
/// [TripChecklistRepository] to keep that file under the project's
/// 800-line cap. [TripChecklistRepository]'s own section methods are thin
/// forwarders to this class, so its public API is unchanged for callers.
class TripChecklistSectionRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();

  Stream<void> watchTripChecklistSectionChanges() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.tripChecklistSections));

  Future<List<domain.TripChecklistSection>> getSectionsForTrip(
    String tripId,
  ) async {
    final rows =
        await (_db.select(_db.tripChecklistSections)
              ..where((s) => s.tripId.equals(tripId))
              ..orderBy([(s) => OrderingTerm.asc(s.sortOrder)]))
            .get();
    return rows.map(_mapSectionRow).toList();
  }

  /// Creates an empty section at the end of the trip's section order.
  Future<domain.TripChecklistSection> createSection({
    required String tripId,
    required String title,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    final sortOrder = await _nextSectionSortOrder(tripId);
    await _db
        .into(_db.tripChecklistSections)
        .insert(
          TripChecklistSectionsCompanion(
            id: Value(id),
            tripId: Value(tripId),
            title: Value(title),
            sortOrder: Value(sortOrder),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    await _syncRepository.markRecordPending(
      entityType: 'tripChecklistSections',
      recordId: id,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
    return domain.TripChecklistSection(
      id: id,
      tripId: tripId,
      title: title,
      sortOrder: sortOrder,
      createdAt: DateTime.fromMillisecondsSinceEpoch(now),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(now),
    );
  }

  Future<void> renameSection(String id, String title) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(
      _db.tripChecklistSections,
    )..where((s) => s.id.equals(id))).write(
      TripChecklistSectionsCompanion(
        title: Value(title),
        updatedAt: Value(now),
      ),
    );
    await _syncRepository.markRecordPending(
      entityType: 'tripChecklistSections',
      recordId: id,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }

  /// Persists a new section order. [orderedIds] must list every section of
  /// the trip exactly once; sort order is the list position.
  ///
  /// Only sections whose position changes are written and queued for sync,
  /// the same reasoning as TripChecklistRepository.moveItem.
  Future<void> reorderSections(String tripId, List<String> orderedIds) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final changedIds = await _db.transaction(() async {
      final sortOrderById = {
        for (final s in await getSectionsForTrip(tripId)) s.id: s.sortOrder,
      };
      final changed = <String>[];
      for (var i = 0; i < orderedIds.length; i++) {
        final current = sortOrderById[orderedIds[i]];
        if (current == null || current == i) continue;
        await (_db.update(_db.tripChecklistSections)..where(
              (s) => s.id.equals(orderedIds[i]) & s.tripId.equals(tripId),
            ))
            .write(
              TripChecklistSectionsCompanion(
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
        entityType: 'tripChecklistSections',
        recordId: id,
        localUpdatedAt: now,
      );
    }
    SyncEventBus.notifyLocalChange();
  }

  /// Deletes a section. When [moveItemsToSectionId] is given, its items are
  /// reassigned there first; otherwise they are deleted with it. There is no
  /// third "leave items without a section" option here -- the diver already
  /// chose between these two in the delete confirmation dialog.
  ///
  /// The read and the writes share one transaction, so a failure part-way
  /// cannot delete the items but keep the section, and an item a sync merge
  /// adds to the section cannot slip in between the read and the delete
  /// without a tombstone. Sync bookkeeping runs after it commits.
  Future<void> deleteSection(String id, {String? moveItemsToSectionId}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final items = await _db.transaction(() async {
      final items = await (_db.select(
        _db.tripChecklistItems,
      )..where((t) => t.sectionId.equals(id))).get();
      if (moveItemsToSectionId != null) {
        await (_db.update(
          _db.tripChecklistItems,
        )..where((t) => t.sectionId.equals(id))).write(
          TripChecklistItemsCompanion(
            sectionId: Value(moveItemsToSectionId),
            updatedAt: Value(now),
          ),
        );
      } else if (items.isNotEmpty) {
        await (_db.delete(
          _db.tripChecklistItems,
        )..where((t) => t.sectionId.equals(id))).go();
      }
      await (_db.delete(
        _db.tripChecklistSections,
      )..where((s) => s.id.equals(id))).go();
      return items;
    });
    for (final item in items) {
      if (moveItemsToSectionId != null) {
        await _syncRepository.markRecordPending(
          entityType: 'tripChecklistItems',
          recordId: item.id,
          localUpdatedAt: now,
        );
      } else {
        await _syncRepository.logDeletion(
          entityType: 'tripChecklistItems',
          recordId: item.id,
        );
      }
    }
    await _syncRepository.logDeletion(
      entityType: 'tripChecklistSections',
      recordId: id,
    );
    SyncEventBus.notifyLocalChange();
  }

  /// Resolves [title] to an existing section of [tripId] (case-insensitive,
  /// matching the grouping fold the UI has always used), or creates one.
  /// Null or blank resolves to no section. Used by the item editor's
  /// section picker and by `applyTemplate`, so re-applying a template is
  /// idempotent against sections exactly as it already is against items.
  Future<String?> findOrCreateSectionId(String tripId, String? title) async {
    final trimmed = title?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    final existing = await getSectionsForTrip(tripId);
    for (final section in existing) {
      if (section.title.toLowerCase() == trimmed.toLowerCase()) {
        return section.id;
      }
    }
    final created = await createSection(tripId: tripId, title: trimmed);
    return created.id;
  }

  /// Pure lookup half of resolving a template section to a trip section for
  /// `TripChecklistRepository.applyTemplate`: case-insensitive title match
  /// against [knownSections], no write. Returns null both for "no section"
  /// and "no match yet" -- the caller tells those apart via [trimmedTitle].
  String? matchSectionByTitle(
    String? trimmedTitle,
    List<domain.TripChecklistSection> knownSections,
  ) {
    if (trimmedTitle == null) return null;
    for (final section in knownSections) {
      if (section.title.toLowerCase() == trimmedTitle.toLowerCase()) {
        return section.id;
      }
    }
    return null;
  }

  /// Transaction-safe variant of [createSection] for
  /// `TripChecklistRepository.applyTemplate`: inserts without the sync
  /// bookkeeping [createSection] does (that must wait until the caller's
  /// outer transaction commits).
  Future<domain.TripChecklistSection> createSectionRow(
    String tripId,
    String title,
    int sortOrder,
  ) async {
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db
        .into(_db.tripChecklistSections)
        .insert(
          TripChecklistSectionsCompanion(
            id: Value(id),
            tripId: Value(tripId),
            title: Value(title),
            sortOrder: Value(sortOrder),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    return domain.TripChecklistSection(
      id: id,
      tripId: tripId,
      title: title,
      sortOrder: sortOrder,
      createdAt: DateTime.fromMillisecondsSinceEpoch(now),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(now),
    );
  }

  Future<int> _nextSectionSortOrder(String tripId) async {
    final row = await _db
        .customSelect(
          'SELECT COALESCE(MAX(sort_order), -1) + 1 AS next '
          'FROM trip_checklist_sections WHERE trip_id = ?',
          variables: [Variable.withString(tripId)],
        )
        .getSingle();
    return row.read<int>('next');
  }

  domain.TripChecklistSection _mapSectionRow(TripChecklistSectionRow row) =>
      domain.TripChecklistSection(
        id: row.id,
        tripId: row.tripId,
        title: row.title,
        sortOrder: row.sortOrder,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
      );
}
