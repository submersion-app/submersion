import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/core/text/text_sort.dart';
import 'package:submersion/features/checklists/domain/entities/checklist_template.dart'
    as domain;
import 'package:submersion/features/checklists/domain/entities/checklist_template_section.dart'
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
      _db.checklistTemplateSections,
    ]),
  );

  Future<List<domain.ChecklistTemplateSection>> getSectionsForTemplate(
    String templateId,
  ) async {
    final rows =
        await (_db.select(_db.checklistTemplateSections)
              ..where((s) => s.templateId.equals(templateId))
              ..orderBy([(s) => OrderingTerm.asc(s.sortOrder)]))
            .get();
    return rows.map(_mapSection).toList();
  }

  Future<domain.ChecklistTemplateSection> createSection({
    required String templateId,
    required String title,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    final sortOrder = await _nextSectionSortOrder(templateId);
    await _db
        .into(_db.checklistTemplateSections)
        .insert(
          ChecklistTemplateSectionsCompanion(
            id: Value(id),
            templateId: Value(templateId),
            title: Value(title),
            sortOrder: Value(sortOrder),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    await _syncRepository.markRecordPending(
      entityType: 'checklistTemplateSections',
      recordId: id,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
    return domain.ChecklistTemplateSection(
      id: id,
      templateId: templateId,
      title: title,
      sortOrder: sortOrder,
      createdAt: DateTime.fromMillisecondsSinceEpoch(now),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(now),
    );
  }

  Future<void> renameSection(String id, String title) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(
      _db.checklistTemplateSections,
    )..where((s) => s.id.equals(id))).write(
      ChecklistTemplateSectionsCompanion(
        title: Value(title),
        updatedAt: Value(now),
      ),
    );
    await _syncRepository.markRecordPending(
      entityType: 'checklistTemplateSections',
      recordId: id,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }

  /// Persists a new section order. [orderedIds] must list every section of
  /// the template exactly once; sort order is the list position.
  Future<void> reorderSections(
    String templateId,
    List<String> orderedIds,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        await (_db.update(_db.checklistTemplateSections)..where(
              (s) =>
                  s.id.equals(orderedIds[i]) & s.templateId.equals(templateId),
            ))
            .write(
              ChecklistTemplateSectionsCompanion(
                sortOrder: Value(i),
                updatedAt: Value(now),
              ),
            );
      }
    });
    for (final id in orderedIds) {
      await _syncRepository.markRecordPending(
        entityType: 'checklistTemplateSections',
        recordId: id,
        localUpdatedAt: now,
      );
    }
    SyncEventBus.notifyLocalChange();
  }

  /// Replace-all save of a template's sections, mirroring [saveItems]: a
  /// section whose id is new (or blank) is inserted, a kept one is updated in
  /// place retaining its original createdAt, and one left out of [sections]
  /// is tombstoned. Used by the template editor, which holds the section
  /// list in memory (so a diver can add/rename/reorder/delete sections while
  /// drafting) and only persists it on Save -- the same reason [saveItems]
  /// exists instead of per-action section repository calls.
  ///
  /// Must run before [saveItems] in the same save so item rows referencing a
  /// newly drafted section's id satisfy the foreign key when they are
  /// (re)inserted.
  Future<void> saveSections(
    String templateId,
    List<domain.ChecklistTemplateSection> sections,
  ) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final resolved =
          <({String id, domain.ChecklistTemplateSection section})>[];
      for (final section in sections) {
        resolved.add((
          id: section.id.isEmpty ? _uuid.v4() : section.id,
          section: section,
        ));
      }
      final keptIds = resolved.map((r) => r.id).toSet();

      late final List<domain.ChecklistTemplateSection> removed;
      await _db.transaction(() async {
        final existing = await getSectionsForTemplate(templateId);
        removed = existing.where((e) => !keptIds.contains(e.id)).toList();
        final existingCreatedAt = {
          for (final e in existing) e.id: e.createdAt.millisecondsSinceEpoch,
        };

        // Only the removed sections are deleted; kept ones are upserted
        // in place. Deleting a kept section, even to reinsert it a moment
        // later, fires ON DELETE SET NULL on every item that references it,
        // and the items only regain their section if the separate saveItems
        // call that follows succeeds.
        if (removed.isNotEmpty) {
          await (_db.delete(
            _db.checklistTemplateSections,
          )..where((s) => s.id.isIn([for (final r in removed) r.id]))).go();
        }
        // An upsert, not insertOrReplace: REPLACE deletes the old row
        // first and so fires the same ON DELETE SET NULL.
        await _db.batch((batch) {
          batch.insertAllOnConflictUpdate(_db.checklistTemplateSections, [
            for (var i = 0; i < resolved.length; i++)
              ChecklistTemplateSectionsCompanion(
                id: Value(resolved[i].id),
                templateId: Value(templateId),
                title: Value(resolved[i].section.title),
                sortOrder: Value(i),
                createdAt: Value(existingCreatedAt[resolved[i].id] ?? now),
                updatedAt: Value(now),
              ),
          ]);
        });
      });

      for (final entry in resolved) {
        await _syncRepository.markRecordPending(
          entityType: 'checklistTemplateSections',
          recordId: entry.id,
          localUpdatedAt: now,
        );
      }
      for (final section in removed) {
        await _syncRepository.logDeletion(
          entityType: 'checklistTemplateSections',
          recordId: section.id,
        );
      }
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to save template sections',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Deletes a section. Its items are not deleted; `section_id` falls back
  /// to null (ON DELETE SET NULL on checklist_template_items.section_id).
  Future<void> deleteSection(String id) async {
    await (_db.delete(
      _db.checklistTemplateSections,
    )..where((s) => s.id.equals(id))).go();
    await _syncRepository.logDeletion(
      entityType: 'checklistTemplateSections',
      recordId: id,
    );
    SyncEventBus.notifyLocalChange();
  }

  /// Resolves [title] to an existing section of [templateId]
  /// (case-insensitive), or creates one. Null or blank resolves to no
  /// section. Used by the item editor and by TripChecklistRepository's
  /// applyTemplate/saveAsTemplate to bridge a trip's sections and a
  /// template's sections by title.
  Future<String?> findOrCreateSectionId(
    String templateId,
    String? title,
  ) async {
    final trimmed = title?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    final existing = await getSectionsForTemplate(templateId);
    for (final section in existing) {
      if (section.title.toLowerCase() == trimmed.toLowerCase()) {
        return section.id;
      }
    }
    final created = await createSection(templateId: templateId, title: trimmed);
    return created.id;
  }

  Future<int> _nextSectionSortOrder(String templateId) async {
    final row = await _db
        .customSelect(
          'SELECT COALESCE(MAX(sort_order), -1) + 1 AS next '
          'FROM checklist_template_sections WHERE template_id = ?',
          variables: [Variable.withString(templateId)],
        )
        .getSingle();
    return row.read<int>('next');
  }

  domain.ChecklistTemplateSection _mapSection(
    ChecklistTemplateSectionRow row,
  ) => domain.ChecklistTemplateSection(
    id: row.id,
    templateId: row.templateId,
    title: row.title,
    sortOrder: row.sortOrder,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
  );

  Future<List<domain.ChecklistTemplate>> getAllTemplates({
    String? diverId,
  }) async {
    try {
      final query = _db.select(_db.checklistTemplates)
        ..orderBy([(t) => OrderingTerm.asc(t.name.collate(Collate.noCase))]);
      if (diverId != null) {
        query.where((t) => t.diverId.equals(diverId) | t.diverId.isNull());
      }
      final rows = await query.get();
      return sortedByText(rows, (r) => r.name).map(_mapTemplate).toList();
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
      final sections = await getSectionsForTemplate(id);
      await (_db.delete(
        _db.checklistTemplateItems,
      )..where((t) => t.templateId.equals(id))).go();
      // checklist_template_sections.template_id has no SQL cascade; must be
      // cleared before the template row itself, same as items, and cannot
      // be skipped on an empty item list (a template can carry sections
      // with no items yet).
      await (_db.delete(
        _db.checklistTemplateSections,
      )..where((s) => s.templateId.equals(id))).go();
      for (final item in items) {
        await _syncRepository.logDeletion(
          entityType: 'checklistTemplateItems',
          recordId: item.id,
        );
      }
      for (final section in sections) {
        await _syncRepository.logDeletion(
          entityType: 'checklistTemplateSections',
          recordId: section.id,
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
                sectionId: Value(entry.item.sectionId),
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
        sectionId: row.sectionId,
        notes: row.notes,
        dueOffsetDays: row.dueOffsetDays,
        sortOrder: row.sortOrder,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
      );
}
