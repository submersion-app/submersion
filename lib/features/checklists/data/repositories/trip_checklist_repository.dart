import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart' hide Trip;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/checklists/data/repositories/checklist_template_repository.dart';
import 'package:submersion/features/checklists/domain/entities/checklist_template.dart'
    as domain;
import 'package:submersion/features/checklists/domain/entities/trip_checklist_item.dart'
    as domain;
import 'package:submersion/features/checklists/domain/entities/trip_checklist_section.dart'
    as domain;
import 'package:submersion/features/trips/domain/entities/trip.dart';

import 'package:submersion/features/checklists/data/repositories/trip_checklist_section_repository.dart';

/// Item CRUD for one of a trip's checklists (issue #3356).
class TripChecklistRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(TripChecklistRepository);
  final _sections = TripChecklistSectionRepository();

  Stream<void> watchTripChecklistChanges() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.tripChecklistItems));

  Stream<void> watchTripChecklistSectionChanges() =>
      _sections.watchTripChecklistSectionChanges();

  Future<List<domain.TripChecklistSection>> getSectionsForChecklist(
    String checklistId,
  ) => _sections.getSectionsForChecklist(checklistId);

  /// Creates an empty section at the end of the checklist's section order.
  Future<domain.TripChecklistSection> createSection({
    required String checklistId,
    required String title,
  }) => _sections.createSection(checklistId: checklistId, title: title);

  Future<void> renameSection(String id, String title) =>
      _sections.renameSection(id, title);

  /// Persists a new section order. [orderedIds] must list every section of
  /// the checklist exactly once; sort order is the list position.
  Future<void> reorderSections(String checklistId, List<String> orderedIds) =>
      _sections.reorderSections(checklistId, orderedIds);

  /// Deletes a section. When [moveItemsToSectionId] is given, its items are
  /// reassigned there first; otherwise they are deleted with it. There is no
  /// third "leave items without a section" option here -- the diver already
  /// chose between these two in the delete confirmation dialog.
  Future<void> deleteSection(String id, {String? moveItemsToSectionId}) =>
      _sections.deleteSection(id, moveItemsToSectionId: moveItemsToSectionId);

  /// Resolves [title] to an existing section of [checklistId]
  /// (case-insensitive, matching the grouping fold the UI has always used),
  /// or creates one. Null or blank resolves to no section. Used by the item
  /// editor's section picker and by [applyTemplate], so re-applying a
  /// template is idempotent against sections exactly as it already is
  /// against items.
  Future<String?> findOrCreateSectionId(String checklistId, String? title) =>
      _sections.findOrCreateSectionId(checklistId, title);

  /// Moves [itemId] to [targetSectionId] (null = no section) and persists
  /// the checklist's full new item order in the same write. [orderedIds]
  /// must list every item of the checklist exactly once, in its new display
  /// order, the same contract [reorderSections] has for sections. One
  /// call covers both a same-section reorder (pass the item's current
  /// section again) and a cross-section move.
  Future<void> moveItem({
    required String checklistId,
    required String itemId,
    required String? targetSectionId,
    required List<String> orderedIds,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    // Only rows whose section or position actually changes are written and
    // queued for sync. Restamping every item in the checklist on each nudge
    // would queue a record per item, and its fresh clock could win a merge
    // over a concurrent edit made to an untouched item on another device.
    final changedIds = await _db.transaction(() async {
      final current = {
        for (final row in await (_db.select(
          _db.tripChecklistItems,
        )..where((t) => t.checklistId.equals(checklistId))).get())
          row.id: row,
      };
      final changed = <String>{};
      final moved = current[itemId];
      if (moved != null && moved.sectionId != targetSectionId) {
        await (_db.update(_db.tripChecklistItems)..where(
              (t) => t.id.equals(itemId) & t.checklistId.equals(checklistId),
            ))
            .write(
              TripChecklistItemsCompanion(
                sectionId: Value(targetSectionId),
                updatedAt: Value(now),
              ),
            );
        changed.add(itemId);
      }
      for (var i = 0; i < orderedIds.length; i++) {
        final row = current[orderedIds[i]];
        if (row == null || row.sortOrder == i) continue;
        await (_db.update(_db.tripChecklistItems)..where(
              (t) =>
                  t.id.equals(orderedIds[i]) &
                  t.checklistId.equals(checklistId),
            ))
            .write(
              TripChecklistItemsCompanion(
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
        entityType: 'tripChecklistItems',
        recordId: id,
        localUpdatedAt: now,
      );
    }
    SyncEventBus.notifyLocalChange();
  }

  /// Every item across every checklist of [tripId] (issue #3356), joined
  /// through `trip_checklists`. Used by the trip overview card, which needs
  /// individual due dates for its overdue/due-soon counts rather than just
  /// the done/total counts [getProgressForTrips] returns.
  Future<List<domain.TripChecklistItem>> getAllItemsForTrip(
    String tripId,
  ) async {
    try {
      final rows =
          await (_db.select(_db.tripChecklistItems).join([
                  innerJoin(
                    _db.tripChecklists,
                    _db.tripChecklists.id.equalsExp(
                      _db.tripChecklistItems.checklistId,
                    ),
                  ),
                ])
                ..where(_db.tripChecklists.tripId.equals(tripId))
                ..orderBy([
                  OrderingTerm.asc(_db.tripChecklists.sortOrder),
                  OrderingTerm.asc(_db.tripChecklists.createdAt),
                  OrderingTerm.asc(_db.tripChecklistItems.sortOrder),
                ]))
              .get();
      return rows
          .map((r) => _mapRow(r.readTable(_db.tripChecklistItems)))
          .toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get checklist items for trip $tripId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<List<domain.TripChecklistItem>> getByChecklistId(
    String checklistId,
  ) async {
    try {
      final rows =
          await (_db.select(_db.tripChecklistItems)
                ..where((t) => t.checklistId.equals(checklistId))
                ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
              .get();
      return rows.map(_mapRow).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get checklist items for checklist $checklistId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<domain.TripChecklistItem> createItem(
    domain.TripChecklistItem item,
  ) async {
    try {
      final id = item.id.isEmpty ? _uuid.v4() : item.id;
      final now = DateTime.now().millisecondsSinceEpoch;
      final sortOrder = await _nextSortOrder(item.checklistId);
      await _db
          .into(_db.tripChecklistItems)
          .insert(
            TripChecklistItemsCompanion(
              id: Value(id),
              checklistId: Value(item.checklistId),
              title: Value(item.title),
              sectionId: Value(item.sectionId),
              notes: Value(item.notes),
              dueDate: Value(item.dueDate?.millisecondsSinceEpoch),
              isDone: Value(item.isDone),
              completedAt: Value(item.completedAt?.millisecondsSinceEpoch),
              sortOrder: Value(sortOrder),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await _syncRepository.markRecordPending(
        entityType: 'tripChecklistItems',
        recordId: id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
      return item.copyWith(
        id: id,
        sortOrder: sortOrder,
        createdAt: DateTime.fromMillisecondsSinceEpoch(now),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(now),
      );
    } catch (e, stackTrace) {
      _log.error(
        'Failed to create checklist item',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> updateItem(domain.TripChecklistItem item) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(
        _db.tripChecklistItems,
      )..where((t) => t.id.equals(item.id))).write(
        TripChecklistItemsCompanion(
          title: Value(item.title),
          sectionId: Value(item.sectionId),
          notes: Value(item.notes),
          dueDate: Value(item.dueDate?.millisecondsSinceEpoch),
          isDone: Value(item.isDone),
          completedAt: Value(item.completedAt?.millisecondsSinceEpoch),
          sortOrder: Value(item.sortOrder),
          updatedAt: Value(now),
        ),
      );
      await _syncRepository.markRecordPending(
        entityType: 'tripChecklistItems',
        recordId: item.id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to update checklist item ${item.id}',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> toggleDone(String id, {required bool isDone}) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(
        _db.tripChecklistItems,
      )..where((t) => t.id.equals(id))).write(
        TripChecklistItemsCompanion(
          isDone: Value(isDone),
          completedAt: Value(isDone ? now : null),
          updatedAt: Value(now),
        ),
      );
      await _syncRepository.markRecordPending(
        entityType: 'tripChecklistItems',
        recordId: id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to toggle checklist item $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> deleteItem(String id) async {
    try {
      await (_db.delete(
        _db.tripChecklistItems,
      )..where((t) => t.id.equals(id))).go();
      await _syncRepository.logDeletion(
        entityType: 'tripChecklistItems',
        recordId: id,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to delete checklist item $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Clears a checklist's items but keeps its sections (the "Clear
  /// checklist" overflow action: its confirmation copy promises only
  /// items are removed, and a diver who laid out empty sections in advance
  /// should not lose that structure by clearing the checklist before a new
  /// trip). Scoped to one checklist: a trip's other checklists are
  /// untouched.
  Future<void> clearItems(String checklistId) async {
    try {
      final existing = await getByChecklistId(checklistId);
      if (existing.isEmpty) return;
      await (_db.delete(
        _db.tripChecklistItems,
      )..where((t) => t.checklistId.equals(checklistId))).go();
      for (final item in existing) {
        await _syncRepository.logDeletion(
          entityType: 'tripChecklistItems',
          recordId: item.id,
        );
      }
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to clear checklist items for checklist $checklistId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Replaces a checklist's entire content with [templateId] (issue #3356):
  /// unlike [clearItems], this also drops the checklist's sections, since
  /// the point is to swap in a different template wholesale, not to clear
  /// items while keeping a manually-laid-out structure. The caller is
  /// responsible for confirming this destructive swap with the diver first.
  ///
  /// The reads, the deletes and [applyTemplate]'s own copy run inside one
  /// shared transaction. A template deleted concurrently makes applyTemplate
  /// throw its StateError, which unwinds the whole transaction, so the
  /// checklist stays exactly as it was rather than emptied with nothing to
  /// show for it. And a row written just before the delete is in the read,
  /// so it gets a tombstone and cannot survive on a peer.
  Future<({int added, int skipped})> replaceWithTemplate({
    required String templateId,
    required String checklistId,
    required Trip trip,
  }) async {
    try {
      final (result, itemIds, sectionIds) = await _db.transaction(() async {
        final items = await getByChecklistId(checklistId);
        final sections = await getSectionsForChecklist(checklistId);
        await (_db.delete(
          _db.tripChecklistItems,
        )..where((t) => t.checklistId.equals(checklistId))).go();
        await (_db.delete(
          _db.tripChecklistSections,
        )..where((s) => s.checklistId.equals(checklistId))).go();
        final applied = await applyTemplate(
          templateId: templateId,
          checklistId: checklistId,
          trip: trip,
        );
        return (
          applied,
          items.map((i) => i.id).toList(),
          sections.map((s) => s.id).toList(),
        );
      });

      // Reached only once the transaction above has committed, so these
      // tombstones never fire for a replace that rolled back.
      await _syncRepository.logDeletions(
        entityType: 'tripChecklistItems',
        recordIds: itemIds,
      );
      await _syncRepository.logDeletions(
        entityType: 'tripChecklistSections',
        recordIds: sectionIds,
      );
      SyncEventBus.notifyLocalChange();
      return result;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to replace checklist $checklistId with template $templateId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Copy-on-apply: copies template items into [checklistId], resolving due
  /// offsets against the trip start date. Items whose title and resolved
  /// section match an existing item of that checklist are skipped so
  /// re-apply is idempotent.
  ///
  /// The transaction only covers the reads and writes; sync bookkeeping
  /// (markRecordPending/notifyLocalChange) runs after it commits so a
  /// rolled-back transaction never leaves stray pending-sync markers.
  Future<({int added, int skipped})> applyTemplate({
    required String templateId,
    required String checklistId,
    required Trip trip,
  }) async {
    try {
      final templateRepository = ChecklistTemplateRepository();
      final now = DateTime.now().millisecondsSinceEpoch;
      final pendingIds = <String>[];
      final pendingSectionIds = <String>[];

      final result = await _db.transaction(() async {
        final template = await templateRepository.getTemplateById(templateId);
        if (template == null) {
          throw StateError('Checklist template $templateId no longer exists');
        }
        final templateItems = await templateRepository.getItemsForTemplate(
          templateId,
        );
        final templateSections = await templateRepository
            .getSectionsForTemplate(templateId);
        final templateSectionTitleById = {
          for (final s in templateSections) s.id: s.title,
        };
        final existing = await getByChecklistId(checklistId);
        final existingKeys = existing
            .map((i) => (i.title, i.sectionId))
            .toSet();
        var sortOrder = await _nextSortOrder(checklistId);
        var added = 0;
        var skipped = 0;
        // Fetched once and grown immutably below as sections are created
        // mid-loop, rather than re-querying every checklist section on
        // every template item.
        var knownSections = await getSectionsForChecklist(checklistId);

        for (final item in templateItems) {
          // Bridge the template's section (its own table now) to a
          // checklist section by title: find an existing one
          // case-insensitively before creating one, the same resolution the
          // item editor's picker uses. The match is looked up (not created)
          // before the skip check below, so a fully-skipped re-apply creates
          // no sections. A placeholder key standing in for "this section
          // doesn't exist among the checklist's sections yet" cannot equal
          // any persisted item's real sectionId (null or an existing uuid),
          // so it never causes a false-positive skip either.
          final trimmedSectionTitle = item.sectionId == null
              ? null
              : templateSectionTitleById[item.sectionId]?.trim();
          final hasSectionTitle =
              trimmedSectionTitle != null && trimmedSectionTitle.isNotEmpty;
          final matchedSectionId = hasSectionTitle
              ? _sections.matchSectionByTitle(
                  trimmedSectionTitle,
                  knownSections,
                )
              : null;
          final comparisonSectionId =
              matchedSectionId ??
              (hasSectionTitle
                  ? '__pending_section__:${trimmedSectionTitle.toLowerCase()}'
                  : null);
          if (existingKeys.contains((item.title, comparisonSectionId))) {
            skipped++;
            continue;
          }
          var sectionId = matchedSectionId;
          if (sectionId == null && hasSectionTitle) {
            // One past the highest sortOrder, not the section count:
            // deleting a section leaves a gap rather than renumbering, so
            // the count can equal a sortOrder already in use.
            final created = await _sections.createSectionRow(
              checklistId,
              trimmedSectionTitle,
              knownSections.fold<int>(
                    -1,
                    (highest, s) =>
                        s.sortOrder > highest ? s.sortOrder : highest,
                  ) +
                  1,
            );
            knownSections = [...knownSections, created];
            pendingSectionIds.add(created.id);
            sectionId = created.id;
          }
          final id = _uuid.v4();
          final dueDate = item.dueOffsetDays == null
              ? null
              : DateTime(
                  trip.startDate.year,
                  trip.startDate.month,
                  trip.startDate.day - item.dueOffsetDays!,
                ).millisecondsSinceEpoch;
          await _db
              .into(_db.tripChecklistItems)
              .insert(
                TripChecklistItemsCompanion(
                  id: Value(id),
                  checklistId: Value(checklistId),
                  title: Value(item.title),
                  sectionId: Value(sectionId),
                  notes: Value(item.notes),
                  dueDate: Value(dueDate),
                  isDone: const Value(false),
                  sortOrder: Value(sortOrder++),
                  createdAt: Value(now),
                  updatedAt: Value(now),
                ),
              );
          pendingIds.add(id);
          added++;
        }

        return (added: added, skipped: skipped);
      });

      // Sync bookkeeping for both the items and any section the loop above
      // created runs after the transaction commits, matching the existing
      // item-only comment above this method: a rolled-back transaction must
      // never leave a stray pending-sync marker.
      for (final id in pendingSectionIds) {
        await _syncRepository.markRecordPending(
          entityType: 'tripChecklistSections',
          recordId: id,
          localUpdatedAt: now,
        );
      }
      for (final id in pendingIds) {
        await _syncRepository.markRecordPending(
          entityType: 'tripChecklistItems',
          recordId: id,
          localUpdatedAt: now,
        );
      }
      if (pendingIds.isNotEmpty || pendingSectionIds.isNotEmpty) {
        SyncEventBus.notifyLocalChange();
      }
      return result;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to apply template $templateId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Reverse copy: snapshot one checklist as a reusable template.
  /// Absolute due dates convert back to offsets from the trip start date
  /// (only when the due date is on or before the start); dateless items
  /// stay dateless.
  Future<domain.ChecklistTemplate> saveAsTemplate({
    required String checklistId,
    required DateTime tripStartDate,
    required String name,
    String? diverId,
  }) async {
    try {
      final templateRepository = ChecklistTemplateRepository();
      final items = await getByChecklistId(checklistId);
      final sections = await getSectionsForChecklist(checklistId);
      final template = await templateRepository.createTemplate(
        domain.ChecklistTemplate(
          id: '',
          diverId: diverId,
          name: name,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      // Bridge the checklist's sections to the new template's own sections
      // by title, resolving each distinct one once (find-or-create is
      // async, so this runs before the synchronous item-mapping pass
      // below).
      final newTemplateSectionIdByChecklistSectionId = <String, String?>{};
      for (final section in sections) {
        newTemplateSectionIdByChecklistSectionId[section.id] =
            await templateRepository.findOrCreateSectionId(
              template.id,
              section.title,
            );
      }
      final templateItems = items.map((item) {
        int? offset;
        final due = item.dueDate;
        if (due != null) {
          // Date-only difference so results are stable across DST
          // transitions: two DateTimes at local midnight always differ by
          // a whole number of calendar days.
          final startDay = DateTime(
            tripStartDate.year,
            tripStartDate.month,
            tripStartDate.day,
          );
          final dueDay = DateTime(due.year, due.month, due.day);
          final days = startDay.difference(dueDay).inDays;
          offset = days >= 0 ? days : null;
        }
        return domain.ChecklistTemplateItem(
          id: '',
          templateId: template.id,
          title: item.title,
          sectionId: item.sectionId == null
              ? null
              : newTemplateSectionIdByChecklistSectionId[item.sectionId],
          notes: item.notes,
          dueOffsetDays: offset,
          sortOrder: item.sortOrder,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }).toList();
      await templateRepository.saveItems(template.id, templateItems);
      return template;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to save checklist $checklistId as template',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Done/total for several trips in one query, keyed by trip id and summed
  /// across every checklist of that trip (issue #3356: a trip's home-screen
  /// badge shows its combined progress rather than favouring one of several
  /// checklists).
  ///
  /// A trip with no items at all is absent from the result rather than
  /// present with zeroes: GROUP BY only yields rows that exist. Callers
  /// ranking trips read that absence as "nothing to show for this one".
  ///
  /// Batched deliberately. The caller (home screen) needs to look past a trip
  /// whose list is empty, and doing that one trip at a time would
  /// fan a per-trip query -- and, through the provider family, a per-trip
  /// table subscription -- out of a widget that rebuilds on every dashboard
  /// paint. Mirrors PreDiveSessionRepository.getItemsForSessions.
  Future<Map<String, ({int done, int total})>> getProgressForTrips(
    List<String> tripIds,
  ) async {
    if (tripIds.isEmpty) return {};
    try {
      // Only the placeholder count is interpolated; every id is bound.
      final placeholders = List.filled(tripIds.length, '?').join(', ');
      final rows = await _db
          .customSelect(
            'SELECT c.trip_id AS trip_id, COUNT(*) AS total, '
            'SUM(CASE WHEN i.is_done THEN 1 ELSE 0 END) AS done '
            'FROM trip_checklist_items i '
            'JOIN trip_checklists c ON c.id = i.checklist_id '
            'WHERE c.trip_id IN ($placeholders) '
            'GROUP BY c.trip_id',
            variables: [for (final id in tripIds) Variable.withString(id)],
            readsFrom: {_db.tripChecklistItems, _db.tripChecklists},
          )
          .get();
      return {
        for (final row in rows)
          row.read<String>('trip_id'): (
            done: row.read<int?>('done') ?? 0,
            total: row.read<int>('total'),
          ),
      };
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get checklist progress in bulk',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<int> _nextSortOrder(String checklistId) async {
    final row = await _db
        .customSelect(
          'SELECT COALESCE(MAX(sort_order), -1) + 1 AS next '
          'FROM trip_checklist_items WHERE checklist_id = ?',
          variables: [Variable.withString(checklistId)],
        )
        .getSingle();
    return row.read<int>('next');
  }

  domain.TripChecklistItem _mapRow(TripChecklistItem row) =>
      domain.TripChecklistItem(
        id: row.id,
        checklistId: row.checklistId,
        title: row.title,
        sectionId: row.sectionId,
        notes: row.notes,
        dueDate: row.dueDate == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(row.dueDate!),
        isDone: row.isDone,
        completedAt: row.completedAt == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(row.completedAt!),
        sortOrder: row.sortOrder,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
      );
}
