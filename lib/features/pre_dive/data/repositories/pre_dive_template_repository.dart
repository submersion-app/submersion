import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template.dart'
    as domain;

class PreDiveTemplateRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(PreDiveTemplateRepository);

  static const _templateEntity = 'preDiveChecklistTemplates';
  static const _itemEntity = 'preDiveChecklistTemplateItems';

  Stream<void> watchTemplatesChanges() => _db.tableUpdates(
    TableUpdateQuery.onAllTables([
      _db.preDiveChecklistTemplates,
      _db.preDiveChecklistTemplateItems,
    ]),
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
          (t) => OrderingTerm.asc(t.name),
        ]);
      final rows = await query.get();
      return rows.map(_mapTemplate).toList();
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
      await (_db.delete(
        _db.preDiveChecklistTemplateItems,
      )..where((t) => t.templateId.equals(id))).go();
      for (final item in items) {
        await _syncRepository.logDeletion(
          entityType: _itemEntity,
          recordId: item.id,
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
                section: Value(entry.item.section),
                title: Value(entry.item.title),
                notes: Value(entry.item.notes),
                sortOrder: Value(i),
                itemType: Value(entry.item.itemType.name),
                valueLabel: Value(entry.item.valueLabel),
                valueUnit: Value(entry.item.valueUnit),
                valueMin: Value(entry.item.valueMin),
                valueMax: Value(entry.item.valueMax),
                isRequired: Value(entry.item.isRequired),
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
    final clone = await createTemplate(
      source.copyWith(
        id: '',
        diverId: diverId,
        name: newName,
        isBuiltIn: false,
        builtinKey: null,
      ),
    );
    await saveItems(clone.id, [
      for (final i in items) i.copyWith(id: '', templateId: clone.id),
    ]);
    return clone;
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
    section: row.section,
    title: row.title,
    notes: row.notes,
    sortOrder: row.sortOrder,
    itemType: domain.PreDiveItemType.parse(row.itemType),
    valueLabel: row.valueLabel,
    valueUnit: row.valueUnit,
    valueMin: row.valueMin,
    valueMax: row.valueMax,
    isRequired: row.isRequired,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
  );
}
