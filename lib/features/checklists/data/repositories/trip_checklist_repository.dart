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

  Future<List<domain.TripChecklistSection>> getSectionsForTrip(String tripId) =>
      _sections.getSectionsForTrip(tripId);

  /// Creates an empty section at the end of the trip's section order.
  Future<domain.TripChecklistSection> createSection({
    required String tripId,
    required String title,
  }) => _sections.createSection(tripId: tripId, title: title);

  Future<void> renameSection(String id, String title) =>
      _sections.renameSection(id, title);

  /// Persists a new section order. [orderedIds] must list every section of
  /// the trip exactly once; sort order is the list position.
  Future<void> reorderSections(String tripId, List<String> orderedIds) =>
      _sections.reorderSections(tripId, orderedIds);

  /// Deletes a section. When [moveItemsToSectionId] is given, its items are
  /// reassigned there first; otherwise they are deleted with it. There is no
  /// third "leave items without a section" option here -- the diver already
  /// chose between these two in the delete confirmation dialog.
  Future<void> deleteSection(String id, {String? moveItemsToSectionId}) =>
      _sections.deleteSection(id, moveItemsToSectionId: moveItemsToSectionId);

  /// Resolves [title] to an existing section of [tripId] (case-insensitive,
  /// matching the grouping fold the UI has always used), or creates one.
  /// Null or blank resolves to no section. Used by the item editor's
  /// section picker and by [applyTemplate], so re-applying a template is
  /// idempotent against sections exactly as it already is against items.
  Future<String?> findOrCreateSectionId(String tripId, String? title) =>
      _sections.findOrCreateSectionId(tripId, title);

  /// Moves [itemId] to [targetSectionId] (null = no section) and persists
  /// the trip's full new item order in the same write. [orderedIds] must
  /// list every item of the trip exactly once, in its new display order --
  /// the same contract [reorderSections] has for sections. One call covers
  /// both a same-section reorder (pass the item's current section again) and
  /// a cross-section move.
  Future<void> moveItem({
    required String tripId,
    required String itemId,
    required String? targetSectionId,
    required List<String> orderedIds,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    // Only rows whose section or position actually changes are written and
    // queued for sync. Restamping every item in the trip on each nudge would
    // queue a record per item, and its fresh clock could win a merge over a
    // concurrent edit made to an untouched item on another device.
    final changedIds = await _db.transaction(() async {
      final current = {
        for (final row in await (_db.select(
          _db.tripChecklistItems,
        )..where((t) => t.tripId.equals(tripId))).get())
          row.id: row,
      };
      final changed = <String>{};
      final moved = current[itemId];
      if (moved != null && moved.sectionId != targetSectionId) {
        await (_db.update(
          _db.tripChecklistItems,
        )..where((t) => t.id.equals(itemId) & t.tripId.equals(tripId))).write(
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
              (t) => t.id.equals(orderedIds[i]) & t.tripId.equals(tripId),
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

  Future<List<domain.TripChecklistItem>> getByTripId(String tripId) async {
    try {
      final rows =
          await (_db.select(_db.tripChecklistItems)
                ..where((t) => t.tripId.equals(tripId))
                ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
              .get();
      return rows.map(_mapRow).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get checklist for trip $tripId',
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
      final sortOrder = await _nextSortOrder(item.tripId);
      await _db
          .into(_db.tripChecklistItems)
          .insert(
            TripChecklistItemsCompanion(
              id: Value(id),
              tripId: Value(item.tripId),
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

  /// Clears a trip's items but keeps its sections (the "Clear checklist"
  /// overflow action -- its confirmation copy promises only items are
  /// removed, and a diver who laid out empty sections in advance should not
  /// lose that structure by clearing the checklist for a new trip).
  Future<void> clearItems(String tripId) async {
    try {
      final existing = await getByTripId(tripId);
      if (existing.isEmpty) return;
      await (_db.delete(
        _db.tripChecklistItems,
      )..where((t) => t.tripId.equals(tripId))).go();
      for (final item in existing) {
        await _syncRepository.logDeletion(
          entityType: 'tripChecklistItems',
          recordId: item.id,
        );
      }
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to clear checklist items for trip $tripId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Bulk cascade used by TripRepository.deleteTrip: unlike [clearItems],
  /// also deletes the trip's sections. trip_checklist_sections.trip_id has
  /// no SQL cascade (children are deleted before the trip, matching this
  /// schema's style), and a trip can carry sections with no items at all
  /// (issue #3360's whole point) so this cannot be skipped just because the
  /// item list is empty.
  Future<void> deleteByTripId(String tripId) async {
    try {
      final existing = await getByTripId(tripId);
      final sections = await getSectionsForTrip(tripId);
      if (existing.isEmpty && sections.isEmpty) return;
      await (_db.delete(
        _db.tripChecklistItems,
      )..where((t) => t.tripId.equals(tripId))).go();
      await (_db.delete(
        _db.tripChecklistSections,
      )..where((s) => s.tripId.equals(tripId))).go();
      for (final item in existing) {
        await _syncRepository.logDeletion(
          entityType: 'tripChecklistItems',
          recordId: item.id,
        );
      }
      for (final section in sections) {
        await _syncRepository.logDeletion(
          entityType: 'tripChecklistSections',
          recordId: section.id,
        );
      }
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to delete checklist for trip $tripId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Copy-on-apply: copies template items into the trip, resolving due
  /// offsets against the trip start date. Items whose title and resolved
  /// section match an existing trip item are skipped so re-apply is
  /// idempotent.
  ///
  /// The transaction only covers the reads and writes; sync bookkeeping
  /// (markRecordPending/notifyLocalChange) runs after it commits so a
  /// rolled-back transaction never leaves stray pending-sync markers.
  Future<({int added, int skipped})> applyTemplate({
    required String templateId,
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
        final existing = await getByTripId(trip.id);
        final existingKeys = existing
            .map((i) => (i.title, i.sectionId))
            .toSet();
        var sortOrder = await _nextSortOrder(trip.id);
        var added = 0;
        var skipped = 0;
        // Fetched once and grown immutably below as sections are created
        // mid-loop, rather than re-querying every trip section on every
        // template item.
        var knownSections = await getSectionsForTrip(trip.id);

        for (final item in templateItems) {
          // Bridge the template's section (its own table now) to a trip
          // section by title: find an existing one case-insensitively
          // before creating one, the same resolution the item editor's
          // picker uses. The match is looked up (not created) before the
          // skip check below, so a fully-skipped re-apply creates no
          // sections -- a placeholder key standing in for "this section
          // doesn't exist among the trip's sections yet" cannot equal any
          // persisted item's real sectionId (null or an existing uuid), so
          // it never causes a false-positive skip either.
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
              trip.id,
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
                  tripId: Value(trip.id),
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

  /// Reverse copy: snapshot a trip's checklist as a reusable template.
  /// Absolute due dates convert back to offsets from the trip start date
  /// (only when the due date is on or before the start); dateless items
  /// stay dateless.
  Future<domain.ChecklistTemplate> saveAsTemplate({
    required String tripId,
    required DateTime tripStartDate,
    required String name,
    String? diverId,
  }) async {
    try {
      final templateRepository = ChecklistTemplateRepository();
      final items = await getByTripId(tripId);
      final sections = await getSectionsForTrip(tripId);
      final template = await templateRepository.createTemplate(
        domain.ChecklistTemplate(
          id: '',
          diverId: diverId,
          name: name,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      // Bridge the trip's sections to the new template's own sections by
      // title, resolving each distinct one once (find-or-create is async,
      // so this runs before the synchronous item-mapping pass below).
      final newTemplateSectionIdByTripSectionId = <String, String?>{};
      for (final section in sections) {
        newTemplateSectionIdByTripSectionId[section.id] =
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
              : newTemplateSectionIdByTripSectionId[item.sectionId],
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
        'Failed to save trip $tripId checklist as template',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<({int done, int total})> getProgress(String tripId) async {
    try {
      final row = await _db
          .customSelect(
            'SELECT COUNT(*) AS total, '
            'SUM(CASE WHEN is_done THEN 1 ELSE 0 END) AS done '
            'FROM trip_checklist_items WHERE trip_id = ?',
            variables: [Variable.withString(tripId)],
            readsFrom: {_db.tripChecklistItems},
          )
          .getSingle();
      return (done: row.read<int?>('done') ?? 0, total: row.read<int>('total'));
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get checklist progress',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Done/total for several trips in one query, keyed by trip id.
  ///
  /// A trip with no items is absent from the result rather than present with
  /// zeroes: GROUP BY only yields rows that exist. Callers ranking trips read
  /// that absence as "nothing to show for this one".
  ///
  /// Batched deliberately. The caller (home screen) needs to look past a trip
  /// whose list is empty, and doing that one `getProgress` at a time would
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
            'SELECT trip_id, COUNT(*) AS total, '
            'SUM(CASE WHEN is_done THEN 1 ELSE 0 END) AS done '
            'FROM trip_checklist_items WHERE trip_id IN ($placeholders) '
            'GROUP BY trip_id',
            variables: [for (final id in tripIds) Variable.withString(id)],
            readsFrom: {_db.tripChecklistItems},
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

  Future<int> _nextSortOrder(String tripId) async {
    final row = await _db
        .customSelect(
          'SELECT COALESCE(MAX(sort_order), -1) + 1 AS next '
          'FROM trip_checklist_items WHERE trip_id = ?',
          variables: [Variable.withString(tripId)],
        )
        .getSingle();
    return row.read<int>('next');
  }

  domain.TripChecklistItem _mapRow(TripChecklistItem row) =>
      domain.TripChecklistItem(
        id: row.id,
        tripId: row.tripId,
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
