import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart'
    hide Dive, ChecklistTemplate, ChecklistTemplateItem;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/checklists/data/repositories/checklist_template_repository.dart';
import 'package:submersion/features/checklists/domain/entities/checklist_template.dart';

import '../../../../helpers/test_database.dart';
import '../records/record_harness.dart';
import 'child_write_harness.dart';

/// A trip's checklists, their sections and items, and the templates they
/// come from, as the trip page's checklist panel keeps them.
void main() {
  late AppDatabase db;
  late ChildWriteHarness h;
  late String tripId;

  Future<String> make(String entity, Map<String, Object?> values) async =>
      (await h.run([createOp(entity, values)])).created.single.id;

  Future<String> checklist([String name = 'Gear']) =>
      make('trip_checklists', {'trip_id': tripId, 'name': name});

  Future<String> section(String list, String title) =>
      make('trip_checklist_sections', {'checklist_id': list, 'title': title});

  Future<String> item(String list, String title, {String? section}) => make(
    'trip_checklist_items',
    {'checklist_id': list, 'title': title, 'section_id': ?section},
  );

  /// A template of two items, one under "Docs", due 3 days before the trip.
  Future<String> template() async {
    final repo = ChecklistTemplateRepository();
    final now = DateTime.now();
    final saved = await repo.createTemplate(
      ChecklistTemplate(
        id: '',
        diverId: kDiverA,
        name: 'Liveaboard',
        createdAt: now,
        updatedAt: now,
      ),
    );
    final docs = await repo.createSection(templateId: saved.id, title: 'Docs');
    await repo.saveItems(saved.id, [
      for (final (i, (title, sectionId, offset)) in [
        ('Passport', docs.id, 3),
        ('Reef hook', null, null),
      ].indexed)
        ChecklistTemplateItem(
          id: '',
          templateId: saved.id,
          title: title,
          sectionId: sectionId,
          dueOffsetDays: offset,
          sortOrder: i,
          createdAt: now,
          updatedAt: now,
        ),
    ]);
    return saved.id;
  }

  Future<List<Map<String, Object?>>> items(String list) async => [
    for (final id in await h.records.list(
      'trip_checklist_items',
      parentId: list,
    ))
      (await h.one('trip_checklist_items', id))!,
  ];

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    h = ChildWriteHarness(db);
    await h.seed();
    tripId = await make('trips', {
      'name': 'Trip',
      'start_date': '2024-03-10',
      'end_date': '2024-03-12',
    });
  });
  tearDown(() => tearDownTestDatabase());

  test('a checklist is created, renamed, reordered and deleted with its items '
      'listed', () async {
    final first = await checklist(' Gear ');
    final second = await checklist('Clothes');
    expect((await h.one('trip_checklists', first))!['name'], 'Gear');

    await h.run([
      updateOp('trip_checklists', second, {'name': 'Kit', 'sort_order': 0}),
    ]);
    final moved = (await h.one('trip_checklists', second))!;
    expect([moved['name'], moved['sort_order']], ['Kit', 0]);

    await section(first, 'Docs');
    await item(first, 'Mask');
    final plan = await h.preview([deleteOp('trip_checklists', first)]);
    expect(plan.items.single.reach.parts, {
      'trip_checklist_items': 1,
      'trip_checklist_sections': 1,
    });
    await h.apply(plan);
    expect(await h.one('trip_checklists', first), isNull);
  });

  test('an item is added, done, moved and deleted', () async {
    final list = await checklist();
    final docs = await section(list, 'Docs');
    final fins = await section(list, 'Fins');
    final mask = await item(list, 'Mask', section: docs);
    final card = await item(list, 'C-card', section: docs);

    await h.run([
      updateOp('trip_checklist_items', mask, {
        'is_done': true,
        'due_date': '2024-03-08',
      }),
    ]);
    final done = (await h.one('trip_checklist_items', mask))!;
    expect(done['is_done'], isTrue);
    expect(done['completed_at'], isNotNull);
    expect(done['due_date'], '2024-03-08');

    final undo = await h.preview([
      updateOp('trip_checklist_items', mask, {'is_done': false}),
    ]);
    final cleared = undo.items.single.fields['completed_at']!;
    expect([cleared.newValue, cleared.indirect], [null, true]);

    await h.run([
      updateOp('trip_checklist_items', card, {'sort_order': 0}),
      updateOp('trip_checklist_items', mask, {'section_id': fins}),
    ]);
    final after = {for (final i in await items(list)) i['id']: i};
    expect(after[mask]!['section_id'], fins);
    expect(
      (after[card]!['sort_order']! as int) <
          (after[mask]!['sort_order']! as int),
      isTrue,
    );

    await h.run([deleteOp('trip_checklist_items', card)]);
    expect(await h.one('trip_checklist_items', card), isNull);
  });

  test('the last section cannot be deleted', () async {
    final list = await checklist();
    final only = await section(list, 'Docs');

    final plan = await h.preview([deleteOp('trip_checklist_sections', only)]);

    expect(plan.items.single.block!.reason, BlockReason.notPermitted);
  });

  test(
    'a section delete takes its items, a merge moves them beside it',
    () async {
      final list = await checklist();
      final docs = await section(list, 'Docs');
      final fins = await section(list, 'Fins');
      final spare = await section(list, 'Spare');
      final card = await item(list, 'C-card', section: docs);
      await item(list, 'Fins', section: fins);

      final merge = await h.preview([
        deleteOp('trip_checklist_sections', docs, mergeInto: spare),
      ]);
      expect(merge.items.single.reach.moved, {'trip_checklist_items': 1});
      await h.apply(merge);
      expect((await h.one('trip_checklist_items', card))!['section_id'], spare);

      final other = await checklist('Other');
      final elsewhere = await section(other, 'Docs');
      final refused = await h.preview([
        deleteOp('trip_checklist_sections', fins, mergeInto: elsewhere),
      ]);
      expect(refused.items.single.block!.reason, BlockReason.invalidValue);

      final drop = await h.preview([deleteOp('trip_checklist_sections', fins)]);
      expect(drop.items.single.reach.parts, {'trip_checklist_items': 1});
    },
  );

  test('applying a template twice adds nothing the second time', () async {
    final id = await template();
    final plan = await h.preview([
      createOp('trip_checklists', {'trip_id': tripId, 'from_template_id': id}),
    ]);
    final create = plan.items.single;
    expect(create.fields['name']!.newValue, 'Liveaboard');
    expect(create.alsoCreates, {
      'trip_checklist_items': 2,
      'trip_checklist_sections': 1,
    });
    final list = (await h.apply(plan)).created.single.id;
    final passport = (await items(
      list,
    )).firstWhere((i) => i['title'] == 'Passport');
    expect(passport['due_date'], '2024-03-07');

    final again = await h.preview([
      updateOp('trip_checklists', list, {'apply_template_id': id}),
    ]);
    expect(again.items.single.alsoCreates, isEmpty);
    await h.apply(again);
    expect(await items(list), hasLength(2));
  });

  test('replacing with a template lists what it drops', () async {
    final id = await template();
    final list = await checklist();
    await section(list, 'Old');
    await item(list, 'Old item');
    await item(list, 'Other item');

    final plan = await h.preview([
      updateOp('trip_checklists', list, {'replace_with_template_id': id}),
    ]);
    final change = plan.items.single;
    expect(change.reach.parts, {
      'trip_checklist_items': 2,
      'trip_checklist_sections': 1,
    });
    expect(change.alsoCreates, {
      'trip_checklist_items': 2,
      'trip_checklist_sections': 1,
    });
    await h.apply(plan);

    expect([
      for (final i in await items(list)) i['title'],
    ], unorderedEquals(['Passport', 'Reef hook']));
  });

  test('saving as a template lists the template it adds', () async {
    final list = await checklist();
    final docs = await section(list, 'Docs');
    await item(list, 'Passport', section: docs);

    final plan = await h.preview([
      updateOp('trip_checklists', list, {'save_as_template_name': 'Mine'}),
    ]);
    expect(plan.items.single.alsoCreates, {
      'checklist_templates': 1,
      'checklist_template_items': 1,
      'checklist_template_sections': 1,
    });
    await h.apply(plan);

    final templates = await db.select(db.checklistTemplates).get();
    expect([for (final t in templates) t.name], contains('Mine'));
  });
}
