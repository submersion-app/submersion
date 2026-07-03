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
import 'package:submersion/features/trips/domain/entities/trip.dart';

class TripChecklistRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(TripChecklistRepository);

  Stream<void> watchTripChecklistChanges() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.tripChecklistItems));

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
              category: Value(item.category),
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
          category: Value(item.category),
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

  /// Bulk cascade used by TripRepository.deleteTrip.
  Future<void> deleteByTripId(String tripId) async {
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
        'Failed to delete checklist for trip $tripId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Copy-on-apply: copies template items into the trip, resolving due
  /// offsets against the trip start date. Items whose title and category
  /// match an existing trip item are skipped so re-apply is idempotent.
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

      final result = await _db.transaction(() async {
        final template = await templateRepository.getTemplateById(templateId);
        if (template == null) {
          throw StateError('Checklist template $templateId no longer exists');
        }
        final templateItems = await templateRepository.getItemsForTemplate(
          templateId,
        );
        final existing = await getByTripId(trip.id);
        final existingKeys = existing.map((i) => (i.title, i.category)).toSet();
        var sortOrder = await _nextSortOrder(trip.id);
        var added = 0;
        var skipped = 0;

        for (final item in templateItems) {
          if (existingKeys.contains((item.title, item.category))) {
            skipped++;
            continue;
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
                  category: Value(item.category),
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

      for (final id in pendingIds) {
        await _syncRepository.markRecordPending(
          entityType: 'tripChecklistItems',
          recordId: id,
          localUpdatedAt: now,
        );
      }
      if (pendingIds.isNotEmpty) {
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
      final template = await templateRepository.createTemplate(
        domain.ChecklistTemplate(
          id: '',
          diverId: diverId,
          name: name,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
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
          category: item.category,
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
        category: row.category,
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
