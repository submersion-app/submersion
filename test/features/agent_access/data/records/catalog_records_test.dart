import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/checklists/data/repositories/checklist_template_repository.dart';
import 'package:submersion/features/dive_roles/data/repositories/dive_role_repository.dart';
import 'package:submersion/features/dive_types/data/repositories/dive_type_repository.dart';
import 'package:submersion/features/pre_dive/data/repositories/pre_dive_template_repository.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tank_presets/data/repositories/tank_preset_repository.dart';
import 'package:submersion/features/weight_presets/data/repositories/weight_preset_repository.dart';

import '../../../../helpers/test_database.dart';
import 'record_harness.dart';

void main() {
  late AppDatabase db;
  late RecordHarness h;
  const t = kSeedTime;

  setUp(() async {
    db = await setUpTestDatabase();
    h = RecordHarness(db);
    await seedTwoDivers(db);
    for (final (id, owner) in [('a', kDiverA), ('b', kDiverB)]) {
      await db
          .into(db.tags)
          .insert(
            TagsCompanion.insert(
              id: 'tag-$id',
              name: 'tag-$id',
              createdAt: t,
              updatedAt: t,
              diverId: Value(owner),
            ),
          );
      await db
          .into(db.diveTypes)
          .insert(
            DiveTypesCompanion.insert(
              id: 'type-$id',
              name: 'type-$id',
              createdAt: t,
              updatedAt: t,
              diverId: Value(owner),
            ),
          );
      await db
          .into(db.diveRoles)
          .insert(
            DiveRolesCompanion.insert(
              id: 'role-$id',
              name: 'role-$id',
              createdAt: t,
              updatedAt: t,
              diverId: Value(owner),
            ),
          );
      await db
          .into(db.tankPresets)
          .insert(
            TankPresetsCompanion.insert(
              id: 'tank-$id',
              name: 'tank-$id',
              displayName: 'Tank $id',
              volumeLiters: 12,
              workingPressureBar: 232,
              material: 'steel',
              createdAt: t,
              updatedAt: t,
              diverId: Value(owner),
            ),
          );
      await db
          .into(db.weightPresets)
          .insert(
            WeightPresetsCompanion.insert(
              id: 'lead-$id',
              displayName: 'Lead $id',
              createdAt: t,
              updatedAt: t,
              diverId: Value(owner),
            ),
          );
      await db
          .into(db.weightPresetEntries)
          .insert(
            WeightPresetEntriesCompanion.insert(
              id: 'entry-$id',
              presetId: 'lead-$id',
              weightType: 'belt',
              amountKg: 4,
              createdAt: t,
            ),
          );
      await db
          .into(db.checklistTemplates)
          .insert(
            ChecklistTemplatesCompanion.insert(
              id: 'list-$id',
              name: 'List $id',
              createdAt: t,
              updatedAt: t,
              diverId: Value(owner),
            ),
          );
      await db
          .into(db.checklistTemplateSections)
          .insert(
            ChecklistTemplateSectionsCompanion.insert(
              id: 'list-sec-$id',
              templateId: 'list-$id',
              title: 'Docs',
              createdAt: t,
              updatedAt: t,
            ),
          );
      await db
          .into(db.checklistTemplateItems)
          .insert(
            ChecklistTemplateItemsCompanion.insert(
              id: 'list-item-$id',
              templateId: 'list-$id',
              title: 'Passport',
              sectionId: Value('list-sec-$id'),
              createdAt: t,
              updatedAt: t,
            ),
          );
      await db
          .into(db.preDiveChecklistTemplates)
          .insert(
            PreDiveChecklistTemplatesCompanion.insert(
              id: 'pre-$id',
              name: 'Pre $id',
              createdAt: t,
              updatedAt: t,
              diverId: Value(owner),
            ),
          );
      await db
          .into(db.preDiveChecklistTemplateItems)
          .insert(
            PreDiveChecklistTemplateItemsCompanion.insert(
              id: 'pre-item-$id',
              templateId: 'pre-$id',
              title: 'Tank pressure',
              itemType: const Value('value'),
              valueLabel: const Value('Pressure'),
              valueUnit: const Value('bar'),
              valueMin: const Value(100),
              createdAt: t,
              updatedAt: t,
            ),
          );
    }
    await db
        .into(db.diveTypes)
        .insert(
          DiveTypesCompanion.insert(
            id: 'stock-type',
            name: 'Stock',
            createdAt: t,
            updatedAt: t,
            isBuiltIn: const Value(true),
          ),
        );
  });
  tearDown(tearDownTestDatabase);

  Future<Set<String>> listed(String entity) async =>
      (await h.list(entity)).toSet();

  test('a tag carries its scopes', () async {
    final doc = (await h.one('tags', 'tag-a'))!;
    expect(doc['name'], 'tag-a');
    expect(doc['scopes'], isA<List>());
    expect(await h.one('tags', 'tag-b'), isNull);
  });

  test('scope matches getAllTags', () async {
    final expected = {
      for (final x in await TagRepository().getAllTags(diverId: kDiverA)) x.id,
    };
    expect(await listed('tags'), expected);
  });

  test('built-in dive types read for every profile', () async {
    expect(await h.one('dive_types', 'stock-type'), isNotNull);
    expect(
      await h.one('dive_types', 'stock-type', diverId: kDiverB),
      isNotNull,
    );
  });

  test('a custom dive type reads only for its owner', () async {
    expect(await h.one('dive_types', 'type-a'), isNotNull);
    expect(await h.one('dive_types', 'type-a', diverId: kDiverB), isNull);
  });

  test('scope matches getAllDiveTypes', () async {
    final expected = {
      for (final x in await DiveTypeRepository().getAllDiveTypes(
        diverId: kDiverA,
      ))
        x.id,
    };
    expect(await listed('dive_types'), expected);
  });

  test('scope matches getAllDiveRoles', () async {
    final expected = {
      for (final x in await DiveRoleRepository().getAllDiveRoles(
        diverId: kDiverA,
      ))
        x.id,
    };
    expect(await listed('dive_roles'), expected);
  });

  test('tank presets are stored rows only', () async {
    final doc = (await h.one('tank_presets', 'tank-a'))!;
    expect(doc['volume_l'], 12.0);
    expect(doc['working_pressure_bar'], 232.0);
    final expected = {
      for (final x in await TankPresetRepository().getCustomPresets(
        diverId: kDiverA,
      ))
        x.id,
    };
    expect(await listed('tank_presets'), expected);
    expect(await h.one('tank_presets', 'al80'), isNull);
  });

  test('weight preset entries carry amount_kg', () async {
    final doc = (await h.one(
      'weight_presets',
      'lead-a',
      include: ['entries'],
    ))!;
    final entry = (doc['entries'] as List).cast<Map>().single;
    expect(entry['amount_kg'], 4.0);
    expect(entry['type'], 'belt');
  });

  test('scope matches getPresets', () async {
    final expected = {
      for (final x in await WeightPresetRepository().getPresets(
        diverId: kDiverA,
      ))
        x.id,
    };
    expect(await listed('weight_presets'), expected);
  });

  test('checklist items come with their template', () async {
    final doc = (await h.one(
      'checklist_templates',
      'list-a',
      include: ['items'],
    ))!;
    final items = doc['items'] as Map;
    expect((items['sections'] as List).cast<Map>().single['title'], 'Docs');
    expect((items['items'] as List).cast<Map>().single['title'], 'Passport');
  });

  test('scope matches getAllTemplates for checklists', () async {
    final expected = {
      for (final x in await ChecklistTemplateRepository().getAllTemplates(
        diverId: kDiverA,
      ))
        x.id,
    };
    expect(await listed('checklist_templates'), expected);
  });

  test('pre-dive item values keep value_label and value_unit', () async {
    final doc = (await h.one(
      'pre_dive_templates',
      'pre-a',
      include: ['items'],
    ))!;
    final item = ((doc['items'] as Map)['items'] as List).cast<Map>().single;
    expect(item['value_label'], 'Pressure');
    expect(item['value_unit'], 'bar');
    expect(item['value_min'], 100.0);
  });

  test('a pre-dive template lists its sections', () async {
    await db
        .into(db.preDiveChecklistTemplateSections)
        .insert(
          PreDiveChecklistTemplateSectionsCompanion.insert(
            id: 'pre-sec',
            templateId: 'pre-a',
            title: 'Gas',
            createdAt: t,
            updatedAt: t,
          ),
        );
    final doc = (await h.one(
      'pre_dive_templates',
      'pre-a',
      include: ['items'],
    ))!;
    final section = ((doc['items'] as Map)['sections'] as List)
        .cast<Map>()
        .single;
    expect(section['title'], 'Gas');
  });

  test('scope matches getAllTemplates for pre-dive templates', () async {
    final expected = {
      for (final x in await PreDiveTemplateRepository().getAllTemplates(
        diverId: kDiverA,
      ))
        x.id,
    };
    expect(await listed('pre_dive_templates'), expected);
  });
}
