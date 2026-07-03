import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/checklists/data/repositories/checklist_template_repository.dart';
import 'package:submersion/features/checklists/domain/entities/checklist_template.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

import '../../../../helpers/test_database.dart';

/// Count deletion_log tombstones for a given entity type + record id.
Future<int> tombstoneCount(String entityType, String recordId) async {
  final db = DatabaseService.instance.database;
  final row = await db
      .customSelect(
        'SELECT COUNT(*) AS c FROM deletion_log '
        'WHERE entity_type = ? AND record_id = ?',
        variables: [
          Variable.withString(entityType),
          Variable.withString(recordId),
        ],
      )
      .getSingle();
  return row.read<int>('c');
}

/// Read (created_at, updated_at) for a checklist_template_items row.
Future<({int createdAt, int updatedAt})> itemTimestamps(String id) async {
  final db = DatabaseService.instance.database;
  final row = await db
      .customSelect(
        'SELECT created_at, updated_at FROM checklist_template_items '
        'WHERE id = ?',
        variables: [Variable.withString(id)],
      )
      .getSingle();
  return (
    createdAt: row.read<int>('created_at'),
    updatedAt: row.read<int>('updated_at'),
  );
}

void main() {
  late ChecklistTemplateRepository repository;

  ChecklistTemplate template({String name = 'Packing'}) => ChecklistTemplate(
    id: '',
    name: name,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  ChecklistTemplateItem item(
    String templateId, {
    String title = 'Wetsuit',
    int? dueOffsetDays,
    String? category,
  }) => ChecklistTemplateItem(
    id: '',
    templateId: templateId,
    title: title,
    category: category,
    dueOffsetDays: dueOffsetDays,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  setUp(() async {
    await setUpTestDatabase();
    repository = ChecklistTemplateRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  group('createTemplate / getAllTemplates / getTemplateById', () {
    test('creates with generated id and reads back', () async {
      final created = await repository.createTemplate(template());
      expect(created.id, isNotEmpty);
      final all = await repository.getAllTemplates();
      expect(all, hasLength(1));
      expect(all.first.name, 'Packing');
      final byId = await repository.getTemplateById(created.id);
      expect(byId, isNotNull);
    });

    test('orders templates by name', () async {
      await repository.createTemplate(template(name: 'Zeta'));
      await repository.createTemplate(template(name: 'Alpha'));
      final all = await repository.getAllTemplates();
      expect(all.map((t) => t.name).toList(), ['Alpha', 'Zeta']);
    });

    test('filtering by diverId includes that diver\'s templates and '
        'diver-less (shared) templates but excludes other divers\'', () async {
      final diverRepo = DiverRepository();
      final now = DateTime.now();
      final diverA = await diverRepo.createDiver(
        Diver(id: '', name: 'Diver A', createdAt: now, updatedAt: now),
      );
      final diverB = await diverRepo.createDiver(
        Diver(id: '', name: 'Diver B', createdAt: now, updatedAt: now),
      );

      await repository.createTemplate(
        ChecklistTemplate(
          id: '',
          diverId: diverA.id,
          name: 'Diver A only',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await repository.createTemplate(
        ChecklistTemplate(
          id: '',
          diverId: diverB.id,
          name: 'Diver B only',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await repository.createTemplate(template(name: 'Shared'));

      final forDiverA = await repository.getAllTemplates(diverId: diverA.id);
      expect(forDiverA.map((t) => t.name).toSet(), {'Diver A only', 'Shared'});
    });
  });

  group('saveItems / getItemsForTemplate', () {
    test('replace-all save assigns sortOrder from list position', () async {
      final tpl = await repository.createTemplate(template());
      await repository.saveItems(tpl.id, [
        item(tpl.id, title: 'B'),
        item(tpl.id, title: 'A', dueOffsetDays: 14, category: 'Gear'),
      ]);
      final items = await repository.getItemsForTemplate(tpl.id);
      expect(items.map((i) => i.title).toList(), ['B', 'A']);
      expect(items[1].dueOffsetDays, 14);
      expect(items[1].category, 'Gear');

      // Re-save with one item: the other is removed.
      await repository.saveItems(tpl.id, [item(tpl.id, title: 'A only')]);
      final after = await repository.getItemsForTemplate(tpl.id);
      expect(after, hasLength(1));
      expect(after.single.title, 'A only');
    });
  });

  group('updateTemplate / deleteTemplate', () {
    test('update changes name, delete removes template and items', () async {
      final tpl = await repository.createTemplate(template());
      await repository.updateTemplate(tpl.copyWith(name: 'Renamed'));
      expect((await repository.getTemplateById(tpl.id))!.name, 'Renamed');

      await repository.saveItems(tpl.id, [item(tpl.id)]);
      await repository.deleteTemplate(tpl.id);
      expect(await repository.getTemplateById(tpl.id), isNull);
      expect(await repository.getItemsForTemplate(tpl.id), isEmpty);
    });
  });

  group('sync contract', () {
    test('saveItems tombstones items removed by a re-save', () async {
      final tpl = await repository.createTemplate(template());
      await repository.saveItems(tpl.id, [
        item(tpl.id, title: 'Keep'),
        item(tpl.id, title: 'Drop'),
      ]);
      final items = await repository.getItemsForTemplate(tpl.id);
      final kept = items.singleWhere((i) => i.title == 'Keep');
      final dropped = items.singleWhere((i) => i.title == 'Drop');

      await repository.saveItems(tpl.id, [kept]);

      expect(
        await tombstoneCount('checklistTemplateItems', dropped.id),
        1,
        reason: 'removed item must be tombstoned for sync',
      );
      expect(
        await tombstoneCount('checklistTemplateItems', kept.id),
        0,
        reason: 'kept item must not be tombstoned',
      );
    });

    test('deleteTemplate tombstones the template and each item', () async {
      final tpl = await repository.createTemplate(template());
      await repository.saveItems(tpl.id, [
        item(tpl.id, title: 'One'),
        item(tpl.id, title: 'Two'),
      ]);
      final items = await repository.getItemsForTemplate(tpl.id);

      await repository.deleteTemplate(tpl.id);

      expect(await tombstoneCount('checklistTemplates', tpl.id), 1);
      for (final it in items) {
        expect(
          await tombstoneCount('checklistTemplateItems', it.id),
          1,
          reason: 'item ${it.title} must be tombstoned',
        );
      }
    });

    test('re-save preserves created_at for kept items and advances '
        'updated_at', () async {
      final tpl = await repository.createTemplate(template());
      await repository.saveItems(tpl.id, [item(tpl.id, title: 'Keep')]);
      final kept = (await repository.getItemsForTemplate(tpl.id)).single;
      final before = await itemTimestamps(kept.id);

      // Ensure the wall clock advances past the original timestamps.
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await repository.saveItems(tpl.id, [kept]);

      final after = await itemTimestamps(kept.id);
      expect(
        after.createdAt,
        before.createdAt,
        reason: 'created_at of a kept item must survive a re-save',
      );
      expect(
        after.updatedAt,
        greaterThan(before.updatedAt),
        reason: 'updated_at must advance on re-save',
      );
    });
  });
}
