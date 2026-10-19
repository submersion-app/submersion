import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/core/text/text_sort.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template.dart'
    as domain;
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template_section.dart'
    as domain;

class PreDiveTemplateRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(PreDiveTemplateRepository);

  static const _templateEntity = 'preDiveChecklistTemplates';
  static const _itemEntity = 'preDiveChecklistTemplateItems';
  static const _sectionEntity = 'preDiveChecklistTemplateSections';

  Stream<void> watchTemplatesChanges() => _db.tableUpdates(
    TableUpdateQuery.onAllTables([
      _db.preDiveChecklistTemplates,
      _db.preDiveChecklistTemplateItems,
      _db.preDiveChecklistTemplateSections,
    ]),
  );

  Future<List<domain.PreDiveChecklistTemplateSection>> getSectionsForTemplate(
    String templateId,
  ) async {
    final rows =
        await (_db.select(_db.preDiveChecklistTemplateSections)
              ..where((s) => s.templateId.equals(templateId))
              ..orderBy([(s) => OrderingTerm.asc(s.sortOrder)]))
            .get();
    return rows.map(_mapSection).toList();
  }

  Future<domain.PreDiveChecklistTemplateSection> createSection({
    required String templateId,
    required String title,
  }) async {
    await _assertNotBuiltIn(templateId);
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    final sortOrder = await _nextSectionSortOrder(templateId);
    await _db
        .into(_db.preDiveChecklistTemplateSections)
        .insert(
          PreDiveChecklistTemplateSectionsCompanion(
            id: Value(id),
            templateId: Value(templateId),
            title: Value(title),
            sortOrder: Value(sortOrder),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    await _syncRepository.markRecordPending(
      entityType: _sectionEntity,
      recordId: id,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
    return domain.PreDiveChecklistTemplateSection(
      id: id,
      templateId: templateId,
      title: title,
      sortOrder: sortOrder,
      createdAt: DateTime.fromMillisecondsSinceEpoch(now),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(now),
    );
  }

  Future<void> renameSection(String id, String title) async {
    await _assertNotBuiltInSection(id);
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(
      _db.preDiveChecklistTemplateSections,
    )..where((s) => s.id.equals(id))).write(
      PreDiveChecklistTemplateSectionsCompanion(
        title: Value(title),
        updatedAt: Value(now),
      ),
    );
    await _syncRepository.markRecordPending(
      entityType: _sectionEntity,
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
        await (_db.update(_db.preDiveChecklistTemplateSections)..where(
              (s) =>
                  s.id.equals(orderedIds[i]) & s.templateId.equals(templateId),
            ))
            .write(
              PreDiveChecklistTemplateSectionsCompanion(
                sortOrder: Value(i),
                updatedAt: Value(now),
              ),
            );
      }
    });
    for (final id in orderedIds) {
      await _syncRepository.markRecordPending(
        entityType: _sectionEntity,
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
  /// list in memory while drafting and only persists it on Save -- the same
  /// reason [saveItems] exists instead of per-action section repository
  /// calls.
  ///
  /// Must run before [saveItems] in the same save so item rows referencing a
  /// newly drafted section's id satisfy the foreign key when they are
  /// (re)inserted.
  Future<void> saveSections(
    String templateId,
    List<domain.PreDiveChecklistTemplateSection> sections,
  ) async {
    try {
      await _assertNotBuiltIn(templateId);
      final now = DateTime.now().millisecondsSinceEpoch;
      final resolved =
          <({String id, domain.PreDiveChecklistTemplateSection section})>[];
      for (final section in sections) {
        resolved.add((
          id: section.id.isEmpty ? _uuid.v4() : section.id,
          section: section,
        ));
      }
      final keptIds = resolved.map((r) => r.id).toSet();

      late final List<domain.PreDiveChecklistTemplateSection> removed;
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
            _db.preDiveChecklistTemplateSections,
          )..where((s) => s.id.isIn([for (final r in removed) r.id]))).go();
        }
        // An upsert, not insertOrReplace: REPLACE deletes the old row
        // first and so fires the same ON DELETE SET NULL.
        await _db.batch((batch) {
          batch
              .insertAllOnConflictUpdate(_db.preDiveChecklistTemplateSections, [
                for (var i = 0; i < resolved.length; i++)
                  PreDiveChecklistTemplateSectionsCompanion(
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
          entityType: _sectionEntity,
          recordId: entry.id,
          localUpdatedAt: now,
        );
      }
      for (final section in removed) {
        await _syncRepository.logDeletion(
          entityType: _sectionEntity,
          recordId: section.id,
        );
      }
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to save pre-dive template sections',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Deletes a section. Its items are not deleted; `section_id` falls back
  /// to null (ON DELETE SET NULL on pre_dive_checklist_template_items).
  Future<void> deleteSection(String id) async {
    await _assertNotBuiltInSection(id);
    await (_db.delete(
      _db.preDiveChecklistTemplateSections,
    )..where((s) => s.id.equals(id))).go();
    await _syncRepository.logDeletion(entityType: _sectionEntity, recordId: id);
    SyncEventBus.notifyLocalChange();
  }

  /// Resolves [title] to an existing section of [templateId]
  /// (case-insensitive), or creates one. Null or blank resolves to no
  /// section.
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
          'FROM pre_dive_checklist_template_sections WHERE template_id = ?',
          variables: [Variable.withString(templateId)],
        )
        .getSingle();
    return row.read<int>('next');
  }

  domain.PreDiveChecklistTemplateSection _mapSection(
    PreDiveChecklistTemplateSectionRow row,
  ) => domain.PreDiveChecklistTemplateSection(
    id: row.id,
    templateId: row.templateId,
    title: row.title,
    sortOrder: row.sortOrder,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
  );

  /// Built-ins are visible to every diver; user templates are scoped to
  /// their owner (or unscoped when diverId is null).
  Future<List<domain.PreDiveChecklistTemplate>> getAllTemplates({
    String? diverId,
  }) async {
    try {
      final query = _db.select(_db.preDiveChecklistTemplates)
        ..where(
          (t) => diverId == null
              ? t.isBuiltIn.equals(true) | t.diverId.isNull()
              : t.isBuiltIn.equals(true) | t.diverId.equals(diverId),
        )
        ..orderBy([
          (t) => OrderingTerm.desc(t.isBuiltIn),
          (t) => OrderingTerm.asc(t.name.collate(Collate.noCase)),
        ]);
      final rows = await query.get();
      return sortedByText(
        rows,
        (r) => r.name,
        groupOf: (r) => r.isBuiltIn,
      ).map(_mapTemplate).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get pre-dive templates',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<domain.PreDiveChecklistTemplate?> getTemplateById(String id) async {
    try {
      final row = await (_db.select(
        _db.preDiveChecklistTemplates,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      return row == null ? null : _mapTemplate(row);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get pre-dive template $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<List<domain.PreDiveChecklistTemplateItem>> getItemsForTemplate(
    String templateId,
  ) async {
    try {
      final rows =
          await (_db.select(_db.preDiveChecklistTemplateItems)
                ..where((t) => t.templateId.equals(templateId))
                ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
              .get();
      return rows.map(_mapItem).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get pre-dive template items',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<domain.PreDiveChecklistTemplate> createTemplate(
    domain.PreDiveChecklistTemplate template,
  ) async {
    try {
      final id = template.id.isEmpty ? _uuid.v4() : template.id;
      final now = DateTime.now().millisecondsSinceEpoch;
      await _db
          .into(_db.preDiveChecklistTemplates)
          .insert(
            PreDiveChecklistTemplatesCompanion(
              id: Value(id),
              diverId: Value(template.diverId),
              name: Value(template.name),
              description: Value(template.description),
              category: Value(template.category),
              strictOrder: Value(template.strictOrder),
              isBuiltIn: Value(template.isBuiltIn),
              builtinKey: Value(template.builtinKey),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await _syncRepository.markRecordPending(
        entityType: _templateEntity,
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
        'Failed to create pre-dive template',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> updateTemplate(domain.PreDiveChecklistTemplate template) async {
    try {
      await _assertNotBuiltIn(template.id);
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(
        _db.preDiveChecklistTemplates,
      )..where((t) => t.id.equals(template.id))).write(
        PreDiveChecklistTemplatesCompanion(
          name: Value(template.name),
          description: Value(template.description),
          category: Value(template.category),
          strictOrder: Value(template.strictOrder),
          updatedAt: Value(now),
        ),
      );
      await _syncRepository.markRecordPending(
        entityType: _templateEntity,
        recordId: template.id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to update pre-dive template',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> deleteTemplate(String id) async {
    try {
      await _assertNotBuiltIn(id);
      final items = await getItemsForTemplate(id);
      final sections = await getSectionsForTemplate(id);
      await (_db.delete(
        _db.preDiveChecklistTemplateItems,
      )..where((t) => t.templateId.equals(id))).go();
      // pre_dive_checklist_template_sections.template_id has no SQL
      // cascade; must be cleared before the template row, same as items,
      // and cannot be skipped on an empty item list.
      await (_db.delete(
        _db.preDiveChecklistTemplateSections,
      )..where((s) => s.templateId.equals(id))).go();
      for (final item in items) {
        await _syncRepository.logDeletion(
          entityType: _itemEntity,
          recordId: item.id,
        );
      }
      for (final section in sections) {
        await _syncRepository.logDeletion(
          entityType: _sectionEntity,
          recordId: section.id,
        );
      }
      await (_db.delete(
        _db.preDiveChecklistTemplates,
      )..where((t) => t.id.equals(id))).go();
      await _syncRepository.logDeletion(
        entityType: _templateEntity,
        recordId: id,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to delete pre-dive template $id',
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
  /// partial item set. Sync bookkeeping runs after the transaction commits.
  Future<void> saveItems(
    String templateId,
    List<domain.PreDiveChecklistTemplateItem> items,
  ) async {
    try {
      await _assertNotBuiltIn(templateId);
      final now = DateTime.now().millisecondsSinceEpoch;
      final resolved =
          <({String id, domain.PreDiveChecklistTemplateItem item})>[];
      for (final item in items) {
        resolved.add((id: item.id.isEmpty ? _uuid.v4() : item.id, item: item));
      }
      final keptIds = resolved.map((r) => r.id).toSet();

      late final List<domain.PreDiveChecklistTemplateItem> removed;
      await _db.transaction(() async {
        final existing = await getItemsForTemplate(templateId);
        removed = existing.where((e) => !keptIds.contains(e.id)).toList();
        final existingCreatedAt = {
          for (final e in existing) e.id: e.createdAt.millisecondsSinceEpoch,
        };

        await (_db.delete(
          _db.preDiveChecklistTemplateItems,
        )..where((t) => t.templateId.equals(templateId))).go();
        await _db.batch((batch) {
          for (var i = 0; i < resolved.length; i++) {
            final entry = resolved[i];
            batch.insert(
              _db.preDiveChecklistTemplateItems,
              PreDiveChecklistTemplateItemsCompanion(
                id: Value(entry.id),
                templateId: Value(templateId),
                sectionId: Value(entry.item.sectionId),
                title: Value(entry.item.title),
                notes: Value(entry.item.notes),
                sortOrder: Value(i),
                itemType: Value(entry.item.itemType.name),
                valueLabel: Value(entry.item.valueLabel),
                valueUnit: Value(entry.item.valueUnit),
                valueMin: Value(entry.item.valueMin),
                valueMax: Value(entry.item.valueMax),
                isRequired: Value(entry.item.isRequired),
                equipmentId: Value(entry.item.equipmentId),
                sourceItemId: Value(entry.item.sourceItemId),
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
          entityType: _itemEntity,
          recordId: entry.id,
          localUpdatedAt: now,
        );
      }
      for (final item in removed) {
        await _syncRepository.logDeletion(
          entityType: _itemEntity,
          recordId: item.id,
        );
      }
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to save pre-dive template items',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Copies a template (built-in or user) plus items into a new editable
  /// user template.
  Future<domain.PreDiveChecklistTemplate> cloneTemplate(
    String templateId, {
    String? diverId,
    required String newName,
  }) async {
    final source = await getTemplateById(templateId);
    if (source == null) {
      throw StateError('Template $templateId no longer exists');
    }
    final items = await getItemsForTemplate(templateId);
    final sections = await getSectionsForTemplate(templateId);
    final clone = await createTemplate(
      source.copyWith(
        id: '',
        diverId: diverId,
        name: newName,
        isBuiltIn: false,
        builtinKey: null,
      ),
    );
    // New section rows for the clone, not shared with the source template
    // (issue #3360) -- renaming or deleting a section in one template must
    // never affect the other. getSectionsForTemplate is ordered by
    // sortOrder, so creating them in this order through the normal
    // append-at-the-end createSection reproduces the same relative order.
    final newSectionIdByOldId = <String, String>{};
    for (final section in sections) {
      final created = await createSection(
        templateId: clone.id,
        title: section.title,
      );
      newSectionIdByOldId[section.id] = created.id;
    }
    // Item ids are minted here rather than left to saveItems, because a
    // cellLinearity item's sourceItemId points at a sibling and has to be
    // rewritten to that sibling's NEW id. Leaving it to saveItems would
    // clone the template with every air/linearity pair silently unlinked,
    // which is the most likely way a diver first meets this feature.
    final newIdByOldId = {for (final i in items) i.id: _uuid.v4()};
    await saveItems(clone.id, [
      for (final i in items)
        i.copyWith(
          id: newIdByOldId[i.id],
          templateId: clone.id,
          sectionId: i.sectionId == null
              ? null
              : newSectionIdByOldId[i.sectionId],
          sourceItemId: i.sourceItemId == null
              ? null
              : newIdByOldId[i.sourceItemId],
        ),
    ]);
    return clone;
  }

  /// Persists the diver's session-start equipment choice for one 'equipment'
  /// item so the next session pre-fills the same device. Not exposed via the
  /// template editor: the only writer is the start-session flow. Callers
  /// must skip this for built-in templates -- their items are shared across
  /// every diver, so writing one diver's equipment there would leak across
  /// divers; a built-in template's equipment choice lives only in that run's
  /// session items.
  Future<void> updateItemEquipment(String itemId, String? equipmentId) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(
        _db.preDiveChecklistTemplateItems,
      )..where((t) => t.id.equals(itemId))).write(
        PreDiveChecklistTemplateItemsCompanion(
          equipmentId: Value(equipmentId),
          updatedAt: Value(now),
        ),
      );
      await _syncRepository.markRecordPending(
        entityType: _itemEntity,
        recordId: itemId,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to update pre-dive template item equipment link',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Guard shared by update/delete/saveItems: built-ins are read-only.
  Future<void> _assertNotBuiltIn(String templateId) async {
    final row = await (_db.select(
      _db.preDiveChecklistTemplates,
    )..where((t) => t.id.equals(templateId))).getSingleOrNull();
    if (row != null && row.isBuiltIn) {
      throw StateError('Built-in pre-dive templates are read-only');
    }
  }

  /// Same guard as [_assertNotBuiltIn], for the section mutators that take
  /// only a section id: resolves the owning template first. A section that
  /// no longer exists has nothing to protect, so this is a no-op rather
  /// than an error -- the delete/rename below will simply affect no rows.
  Future<void> _assertNotBuiltInSection(String sectionId) async {
    final section = await (_db.select(
      _db.preDiveChecklistTemplateSections,
    )..where((s) => s.id.equals(sectionId))).getSingleOrNull();
    if (section != null) await _assertNotBuiltIn(section.templateId);
  }

  domain.PreDiveChecklistTemplate _mapTemplate(PreDiveChecklistTemplate row) =>
      domain.PreDiveChecklistTemplate(
        id: row.id,
        diverId: row.diverId,
        name: row.name,
        description: row.description,
        category: row.category,
        strictOrder: row.strictOrder,
        isBuiltIn: row.isBuiltIn,
        builtinKey: row.builtinKey,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
      );

  domain.PreDiveChecklistTemplateItem _mapItem(
    PreDiveChecklistTemplateItem row,
  ) => domain.PreDiveChecklistTemplateItem(
    id: row.id,
    templateId: row.templateId,
    sectionId: row.sectionId,
    title: row.title,
    notes: row.notes,
    sortOrder: row.sortOrder,
    itemType: domain.PreDiveItemType.parse(row.itemType),
    valueLabel: row.valueLabel,
    valueUnit: row.valueUnit,
    valueMin: row.valueMin,
    valueMax: row.valueMax,
    isRequired: row.isRequired,
    equipmentId: row.equipmentId,
    sourceItemId: row.sourceItemId,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
  );
}
