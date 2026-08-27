import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/pre_dive/data/repositories/pre_dive_template_repository.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template.dart'
    as domain;

import '../../../../helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late PreDiveTemplateRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = PreDiveTemplateRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<int> tombstoneCount(String entityType, String recordId) async {
    final db = DatabaseService.instance.database;
    final rows = await db
        .customSelect(
          'SELECT COUNT(*) AS n FROM deletion_log '
          'WHERE entity_type = ? AND record_id = ?',
          variables: [Variable(entityType), Variable(recordId)],
        )
        .get();
    return rows.first.read<int>('n');
  }

  domain.PreDiveChecklistTemplate template({String name = 'BWRAF'}) {
    final now = DateTime.now();
    return domain.PreDiveChecklistTemplate(
      id: '',
      name: name,
      createdAt: now,
      updatedAt: now,
    );
  }

  domain.PreDiveChecklistTemplateItem item(
    String templateId,
    String title, {
    int order = 0,
  }) {
    final now = DateTime.now();
    return domain.PreDiveChecklistTemplateItem(
      id: '',
      templateId: templateId,
      title: title,
      sortOrder: order,
      createdAt: now,
      updatedAt: now,
    );
  }

  test('creates with generated id and reads back', () async {
    final created = await repository.createTemplate(template());
    expect(created.id, isNotEmpty);
    // beforeOpen seeds the four built-ins; user templates come after them.
    final all = await repository.getAllTemplates();
    final userTemplates = all.where((t) => !t.isBuiltIn).toList();
    expect(userTemplates, hasLength(1));
    expect(userTemplates.first.name, 'BWRAF');
  });

  test('saveItems round-trips typed fields sorted by order', () async {
    final tpl = await repository.createTemplate(template());
    await repository.saveItems(tpl.id, [
      item(tpl.id, 'Assemble', order: 0),
      item(tpl.id, 'Cell 1', order: 1).copyWith(
        itemType: domain.PreDiveItemType.value,
        valueLabel: 'mV',
        valueUnit: 'mV',
        valueMin: 8.5,
        valueMax: 13.0,
        isRequired: true,
      ),
    ]);
    final items = await repository.getItemsForTemplate(tpl.id);
    expect(items.map((i) => i.title).toList(), ['Assemble', 'Cell 1']);
    expect(items[1].itemType, domain.PreDiveItemType.value);
    expect(items[1].valueMin, 8.5);
    expect(items[1].isRequired, isTrue);
  });

  test('deleteTemplate tombstones the template and each item', () async {
    final tpl = await repository.createTemplate(template());
    await repository.saveItems(tpl.id, [
      item(tpl.id, 'One'),
      item(tpl.id, 'Two', order: 1),
    ]);
    final items = await repository.getItemsForTemplate(tpl.id);
    await repository.deleteTemplate(tpl.id);
    expect(await tombstoneCount('preDiveChecklistTemplates', tpl.id), 1);
    for (final it in items) {
      expect(await tombstoneCount('preDiveChecklistTemplateItems', it.id), 1);
    }
    final remaining = await repository.getAllTemplates();
    expect(remaining.where((t) => !t.isBuiltIn), isEmpty);
  });

  test('built-in templates reject update, delete, and saveItems', () async {
    final created = await repository.createTemplate(
      template(name: 'Built-in').copyWith(isBuiltIn: true, builtinKey: 'k'),
    );
    expect(
      () => repository.updateTemplate(created.copyWith(name: 'X')),
      throwsStateError,
    );
    expect(() => repository.deleteTemplate(created.id), throwsStateError);
    expect(() => repository.saveItems(created.id, const []), throwsStateError);
  });

  test('cloneTemplate copies items as an editable user template', () async {
    final builtIn = await repository.createTemplate(
      template(name: 'CCR Build').copyWith(isBuiltIn: true, builtinKey: 'ccr'),
    );
    final user = await repository.createTemplate(template(name: 'Mine'));
    await repository.saveItems(user.id, [item(user.id, 'Step 1')]);
    final clone = await repository.cloneTemplate(
      user.id,
      newName: 'Mine (copy)',
    );
    expect(clone.id, isNot(user.id));
    expect(clone.isBuiltIn, isFalse);
    expect(clone.builtinKey, isNull);
    final cloneItems = await repository.getItemsForTemplate(clone.id);
    expect(cloneItems.single.title, 'Step 1');
    expect(cloneItems.single.templateId, clone.id);
    // Built-in templates are clonable too (metadata only, no items yet).
    final builtInClone = await repository.cloneTemplate(
      builtIn.id,
      newName: 'CCR (copy)',
    );
    expect(builtInClone.isBuiltIn, isFalse);
  });

  test(
    'getAllTemplates scopes by diver but always includes built-ins',
    () async {
      // Minimal diver rows so the diver_id FK resolves.
      final db = DatabaseService.instance.database;
      for (final diverId in ['diver-1', 'diver-2']) {
        await db.customStatement(
          'INSERT INTO divers (id, name, created_at, updated_at) '
          "VALUES ('$diverId', '$diverId', 0, 0)",
        );
      }
      await repository.createTemplate(
        template(
          name: 'Global built-in',
        ).copyWith(isBuiltIn: true, builtinKey: 'g'),
      );
      await repository.createTemplate(
        template(name: 'Mine').copyWith(diverId: 'diver-1'),
      );
      await repository.createTemplate(
        template(name: 'Theirs').copyWith(diverId: 'diver-2'),
      );
      final mine = await repository.getAllTemplates(diverId: 'diver-1');
      final names = mine.map((t) => t.name).toSet();
      expect(names, containsAll({'Global built-in', 'Mine'}));
      expect(names, isNot(contains('Theirs')));
    },
  );
}
