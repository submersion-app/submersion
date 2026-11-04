import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';

import '../../../../helpers/test_database.dart';
import 'child_write_harness.dart';

/// Checklist and pre-dive templates, written whole with their sections and
/// items, as the template edit pages save them.
void main() {
  late AppDatabase db;
  late ChildWriteHarness h;

  Future<String> make(String entity, Map<String, Object?> values) async =>
      (await h.run([createOp(entity, values)])).created.single.id;

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    h = ChildWriteHarness(db);
    await h.seed();
  });
  tearDown(() => tearDownTestDatabase());

  test(
    'a checklist template is written with sections and items in order',
    () async {
      final id = await make('checklist_templates', {
        'name': ' Liveaboard ',
        'sections': [
          {'title': 'Docs'},
          {'title': 'Gear'},
        ],
        'items': [
          {'title': 'Passport', 'section': 'Docs', 'due_offset_days': 7},
          {'title': 'Fins', 'section': 'Gear'},
          {'title': 'Snacks'},
        ],
      });
      final items =
          await (db.select(db.checklistTemplateItems)
                ..where((i) => i.templateId.equals(id))
                ..orderBy([(i) => OrderingTerm.asc(i.sortOrder)]))
              .get();
      expect([for (final i in items) i.title], ['Passport', 'Fins', 'Snacks']);
      expect(items.first.dueOffsetDays, 7);

      final same = await h.preview([
        updateOp('checklist_templates', id, {
          'items': [
            {'title': 'Passport', 'section': 'Docs', 'due_offset_days': 7},
            {'title': 'Fins', 'section': 'Gear'},
            {'title': 'Snacks'},
          ],
        }),
      ]);
      expect(same.unchanged.single.id, id);

      final refused = await h.preview([
        updateOp('checklist_templates', id, {
          'items': [
            {'title': 'Mask', 'section': 'Nowhere'},
          ],
        }),
      ]);
      expect(refused.items.single.block!.reason, BlockReason.invalidValue);

      await h.run([deleteOp('checklist_templates', id)]);
      expect(await db.select(db.checklistTemplateItems).get(), isEmpty);
    },
  );

  test('a pre-dive built-in is refused but can be cloned', () async {
    final builtIn = (await (db.select(
      db.preDiveChecklistTemplates,
    )..where((t) => t.isBuiltIn.equals(true))).get()).first;

    final plan = await h.preview([
      updateOp('pre_dive_templates', builtIn.id, {'name': 'Mine'}),
    ]);
    expect(plan.items.single.block!.reason, BlockReason.notPermitted);
    final drop = await h.preview([deleteOp('pre_dive_templates', builtIn.id)]);
    expect(drop.items.single.block!.reason, BlockReason.notPermitted);

    final clone = await make('pre_dive_templates', {
      'name': 'My copy',
      'clone_of': builtIn.id,
    });
    final copied = await (db.select(
      db.preDiveChecklistTemplateItems,
    )..where((i) => i.templateId.equals(clone))).get();
    final source = await (db.select(
      db.preDiveChecklistTemplateItems,
    )..where((i) => i.templateId.equals(builtIn.id))).get();
    expect(copied, hasLength(source.length));
  });

  test('a cell linearity item needs its source item', () async {
    final plan = await h.preview([
      createOp('pre_dive_templates', {
        'name': 'CCR',
        'items': [
          {'title': 'Cell 1 air', 'item_type': 'value', 'value_unit': 'mV'},
          {'title': 'Cell 1 O2', 'item_type': 'cellLinearity'},
        ],
      }),
    ]);
    expect(plan.items.single.block!.reason, BlockReason.invalidValue);

    final id = await make('pre_dive_templates', {
      'name': 'CCR',
      'strict_order': true,
      'items': [
        {'title': 'Cell 1 air', 'item_type': 'value', 'value_unit': 'mV'},
        {'title': 'Cell 1 O2', 'item_type': 'cellLinearity', 'source_index': 0},
      ],
    });
    final items =
        await (db.select(db.preDiveChecklistTemplateItems)
              ..where((i) => i.templateId.equals(id))
              ..orderBy([(i) => OrderingTerm.asc(i.sortOrder)]))
            .get();
    expect(items.last.sourceItemId, items.first.id);
  });

  test('bounds on a check item are refused', () async {
    final plan = await h.preview([
      createOp('pre_dive_templates', {
        'name': 'Basic',
        'items': [
          {'title': 'Air on', 'value_min': 1},
        ],
      }),
      createOp('pre_dive_templates', {
        'name': 'Basic',
        'items': [
          {
            'title': 'PO2',
            'item_type': 'value',
            'value_min': 2,
            'value_max': 1,
          },
        ],
      }),
    ]);

    for (final item in plan.items) {
      expect(item.block!.reason, BlockReason.invalidValue);
    }
  });
}
