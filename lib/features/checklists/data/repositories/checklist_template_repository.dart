import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/checklists/domain/entities/checklist_template.dart'
    as domain;

class ChecklistTemplateRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(ChecklistTemplateRepository);

  Stream<void> watchTemplatesChanges() => _db.tableUpdates(
    TableUpdateQuery.onAllTables([
      _db.checklistTemplates,
      _db.checklistTemplateItems,
    ]),
  );

  Future<List<domain.ChecklistTemplate>> getAllTemplates({
    String? diverId,
  }) async {
    try {
      final query = _db.select(_db.checklistTemplates)
        ..orderBy([(t) => OrderingTerm.asc(t.name)]);
      if (diverId != null) {
        query.where((t) => t.diverId.equals(diverId) | t.diverId.isNull());
      }
      final rows = await query.get();
      return rows.map(_mapTemplate).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get checklist templates',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<domain.ChecklistTemplate?> getTemplateById(String id) async {
    try {
      final row = await (_db.select(
        _db.checklistTemplates,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      return row == null ? null : _mapTemplate(row);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get checklist template $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<List<domain.ChecklistTemplateItem>> getItemsForTemplate(
    String templateId,
  ) async {
    try {
      final rows =
          await (_db.select(_db.checklistTemplateItems)
                ..where((t) => t.templateId.equals(templateId))
                ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
              .get();
      return rows.map(_mapItem).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get template items',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<domain.ChecklistTemplate> createTemplate(
    domain.ChecklistTemplate template,
  ) async {
    try {
      final id = template.id.isEmpty ? _uuid.v4() : template.id;
      final now = DateTime.now().millisecondsSinceEpoch;
      await _db
          .into(_db.checklistTemplates)
          .insert(
            ChecklistTemplatesCompanion(
              id: Value(id),
              diverId: Value(template.diverId),
              name: Value(template.name),
              description: Value(template.description),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await _syncRepository.markRecordPending(
        entityType: 'checklistTemplates',
        recordId: id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
      return template.copyWith(
        id: id,
        createdAt: DateTime.fromMillisecondsSinceEpoch(now),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(now),
      );
    } catch (e, stackTrace) {
      _log.error(
        'Failed to create checklist template',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> updateTemplate(domain.ChecklistTemplate template) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(
        _db.checklistTemplates,
      )..where((t) => t.id.equals(template.id))).write(
        ChecklistTemplatesCompanion(
          name: Value(template.name),
          description: Value(template.description),
          updatedAt: Value(now),
        ),
      );
      await _syncRepository.markRecordPending(
        entityType: 'checklistTemplates',
        recordId: template.id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to update checklist template',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> deleteTemplate(String id) async {
    try {
      final items = await getItemsForTemplate(id);
      await (_db.delete(
        _db.checklistTemplateItems,
      )..where((t) => t.templateId.equals(id))).go();
      for (final item in items) {
        await _syncRepository.logDeletion(
          entityType: 'checklistTemplateItems',
          recordId: item.id,
        );
      }
      await (_db.delete(
        _db.checklistTemplates,
      )..where((t) => t.id.equals(id))).go();
      await _syncRepository.logDeletion(
        entityType: 'checklistTemplates',
        recordId: id,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to delete checklist template $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Replace-all save of a template's items. sortOrder is assigned from
  /// list position; removed items are tombstoned; kept items retain their
  /// original createdAt. The read-existing/delete/reinsert sequence runs in
  /// one transaction so a failure mid-save cannot leave the template with a
  /// partial item set. Sync bookkeeping (markRecordPending/logDeletion) runs
  /// only after the transaction commits.
  Future<void> saveItems(
    String templateId,
    List<domain.ChecklistTemplateItem> items,
  ) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final resolved = <({String id, domain.ChecklistTemplateItem item})>[];
      for (final item in items) {
        resolved.add((id: item.id.isEmpty ? _uuid.v4() : item.id, item: item));
      }
      final keptIds = resolved.map((r) => r.id).toSet();

      late final List<domain.ChecklistTemplateItem> removed;
      await _db.transaction(() async {
        final existing = await getItemsForTemplate(templateId);
        removed = existing.where((e) => !keptIds.contains(e.id)).toList();
        final existingCreatedAt = {
          for (final e in existing) e.id: e.createdAt.millisecondsSinceEpoch,
        };

        await (_db.delete(
          _db.checklistTemplateItems,
        )..where((t) => t.templateId.equals(templateId))).go();
        await _db.batch((batch) {
          for (var i = 0; i < resolved.length; i++) {
            final entry = resolved[i];
            batch.insert(
              _db.checklistTemplateItems,
              ChecklistTemplateItemsCompanion(
                id: Value(entry.id),
                templateId: Value(templateId),
                title: Value(entry.item.title),
                category: Value(entry.item.category),
                notes: Value(entry.item.notes),
                dueOffsetDays: Value(entry.item.dueOffsetDays),
                sortOrder: Value(i),
                createdAt: Value(existingCreatedAt[entry.id] ?? now),
                updatedAt: Value(now),
              ),
              mode: InsertMode.insertOrReplace,
            );
          }
        });
      });

      for (final entry in resolved) {
        await _syncRepository.markRecordPending(
          entityType: 'checklistTemplateItems',
          recordId: entry.id,
          localUpdatedAt: now,
        );
      }
      for (final item in removed) {
        await _syncRepository.logDeletion(
          entityType: 'checklistTemplateItems',
          recordId: item.id,
        );
      }
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to save template items',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  domain.ChecklistTemplate _mapTemplate(ChecklistTemplate row) =>
      domain.ChecklistTemplate(
        id: row.id,
        diverId: row.diverId,
        name: row.name,
        description: row.description,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
      );

  domain.ChecklistTemplateItem _mapItem(ChecklistTemplateItem row) =>
      domain.ChecklistTemplateItem(
        id: row.id,
        templateId: row.templateId,
        title: row.title,
        category: row.category,
        notes: row.notes,
        dueOffsetDays: row.dueOffsetDays,
        sortOrder: row.sortOrder,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
      );
}
