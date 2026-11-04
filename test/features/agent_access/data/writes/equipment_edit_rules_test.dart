import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/dive_computer/data/clock_sync_preferences.dart';

import '../../../../helpers/test_database.dart';
import '../records/record_harness.dart';
import 'child_write_harness.dart';

/// The rules the equipment edit page applies on a save that an agent's save
/// keeps too: what a type change or a legacy row does, a stray colour, the
/// devices whose names follow the item's, and what a delete forgets.
void main() {
  late AppDatabase db;
  late ChildWriteHarness h;
  const t = kSeedTime;

  Future<void> gear(
    String id,
    String type, {
    String status = 'active',
    bool active = true,
    String? parent,
  }) => db
      .into(db.equipment)
      .insert(
        EquipmentCompanion.insert(
          id: id,
          name: 'Gear $id',
          type: type,
          createdAt: t,
          updatedAt: t,
          diverId: const Value(kDiverA),
          status: Value(status),
          isActive: Value(active),
          parentEquipmentId: Value(parent),
        ),
      );

  Future<Map<String, Object?>> doc(String id) async =>
      (await h.one('equipment', id))!;

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    h = ChildWriteHarness(db);
    await h.seed();
  });
  tearDown(() => tearDownTestDatabase());

  test('a type change drops a parent the new type cannot hold', () async {
    await gear('torch', 'light');
    await gear('cell', 'battery', parent: 'torch');

    final plan = await h.preview([
      updateOp('equipment', 'cell', {'type': 'o2Cell'}),
    ]);

    final parent = plan.items.single.fields['parent_equipment_id']!;
    expect(
      [parent.oldValue, parent.newValue, parent.indirect],
      ['torch', null, true],
    );
  });

  test(
    'a part is fitted only to an item in the kit, and not while wanted',
    () async {
      await gear('torch', 'light');
      await gear('old', 'light', status: 'retired', active: false);

      final plan = await h.preview([
        createOp('equipment', {
          'name': 'Spare',
          'type': 'battery',
          'status': 'wanted',
          'parent_equipment_id': 'torch',
        }),
        createOp('equipment', {
          'name': 'Cell',
          'type': 'battery',
          'parent_equipment_id': 'old',
        }),
      ]);

      for (final item in plan.items) {
        expect(item.block!.reason, BlockReason.invalidValue);
      }
    },
  );

  // A legacy row out of the kit with an in-kit status reads as retired on
  // the edit page, so a save does not quietly put it back (#636).
  test('a legacy inactive item stays out of the kit on an edit', () async {
    await gear('fins', 'fins', active: false);

    final plan = await h.preview([
      updateOp('equipment', 'fins', {'notes': 'Split straps'}),
    ]);

    final fields = plan.items.single.fields;
    expect(fields.containsKey('is_active'), isFalse);
    expect(fields['status']!.newValue, 'retired');
    expect(fields['status']!.indirect, isTrue);
    await h.apply(plan);
    expect((await doc('fins'))['is_active'], isFalse);
  });

  test('a stray colour stays as a custom field', () async {
    await gear('cell', 'o2Cell');
    await db
        .into(db.equipmentAttributes)
        .insert(
          EquipmentAttributesCompanion.insert(
            id: 'attr_cell_color',
            equipmentId: 'cell',
            attrKey: 'color',
            valueText: const Value('Red'),
            createdAt: t,
            updatedAt: t,
          ),
        );

    final plan = await h.preview([
      updateOp('equipment', 'cell', {'notes': 'Logged'}),
    ]);
    expect(plan.items.single.fields.containsKey('attributes'), isFalse);
    await h.apply(plan);

    final attributes = (await doc('cell'))['attributes']! as List;
    expect(attributes.single, containsPair('key', 'color'));
    expect(attributes.single, containsPair('is_custom', true));
  });

  test('a device already named apart from its item is listed', () async {
    await gear('perdix', 'computer');
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion.insert(
            id: 'dc1',
            name: 'Old name',
            createdAt: t,
            updatedAt: t,
            diverId: const Value(kDiverA),
            equipmentId: const Value('perdix'),
          ),
        );

    final plan = await h.preview([
      updateOp('equipment', 'perdix', {'brand': 'Shearwater'}),
    ]);

    expect(plan.items.single.alsoChanges, {'dive_computers': 1});
  });

  test(
    'custom attributes keep their own order after the built-in ones',
    () async {
      await gear('torch', 'light');

      await h.run([
        updateOp('equipment', 'torch', {
          'attributes': [
            {'key': 'lumens', 'value_num': 1200},
            {'key': 'Mount', 'is_custom': true, 'value_text': 'Goodman'},
            {'key': 'Bulb', 'is_custom': true, 'value_text': 'LED'},
          ],
        }),
      ]);

      final rows = await (db.select(
        db.equipmentAttributes,
      )..where((a) => a.equipmentId.equals('torch') & a.isCustom)).get();
      expect(
        {for (final r in rows) r.attrKey: r.sortOrder},
        {'Mount': 0, 'Bulb': 1},
      );
    },
  );

  test('deleting a computer item forgets its clock sync choice', () async {
    SharedPreferences.setMockInitialValues({
      '${ClockSyncPreferences.overridePrefix}dc1': true,
      '${ClockSyncPreferences.supportPrefix}dc1': true,
    });
    addTearDown(() => SharedPreferences.setMockInitialValues({}));
    await gear('perdix', 'computer');
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion.insert(
            id: 'dc1',
            name: 'Gear perdix',
            createdAt: t,
            updatedAt: t,
            diverId: const Value(kDiverA),
            equipmentId: const Value('perdix'),
          ),
        );

    await h.run([deleteOp('equipment', 'perdix')]);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), isEmpty);
  });
}
