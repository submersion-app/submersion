import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/gear_template_dive_queries.dart';
import 'package:submersion/features/equipment/data/services/dive_equipment_defaulter.dart';
import 'package:submersion/features/equipment/data/services/equipment_set_for_computer_linker.dart';

import '../../../../helpers/test_database.dart';

/// A set applies the gear of the sets it includes as well as its own
/// (issue #4525), on every path that reads a set's members.
void main() {
  late AppDatabase db;
  final t = DateTime(2026, 11, 1).millisecondsSinceEpoch;

  Future<void> gear(String id, {String type = 'regulator'}) => db
      .into(db.equipment)
      .insert(
        EquipmentCompanion.insert(
          id: id,
          name: id,
          type: type,
          diverId: const Value('d1'),
          createdAt: t,
          updatedAt: t,
        ),
      );

  Future<void> set(
    String id,
    List<String> members, {
    bool isDefault = false,
    bool autoApply = false,
    List<String> includes = const [],
  }) async {
    await db
        .into(db.equipmentSets)
        .insert(
          EquipmentSetsCompanion.insert(
            id: id,
            diverId: const Value('d1'),
            name: id,
            isDefault: Value(isDefault),
            autoApplyOnComputerImport: Value(autoApply),
            createdAt: t,
            updatedAt: t,
          ),
        );
    for (final member in members) {
      await db
          .into(db.equipmentSetItems)
          .insert(
            EquipmentSetItemsCompanion.insert(setId: id, equipmentId: member),
          );
    }
    for (final (i, included) in includes.indexed) {
      await db
          .into(db.equipmentSetIncludes)
          .insert(
            EquipmentSetIncludesCompanion.insert(
              id: '$id-inc-$i',
              setId: id,
              includedSetId: included,
              sortOrder: Value(i),
              createdAt: t,
            ),
          );
    }
  }

  Future<void> dive(String id) => db
      .into(db.dives)
      .insert(
        DivesCompanion.insert(
          id: id,
          diverId: const Value('d1'),
          diveDateTime: t,
          createdAt: t,
          updatedAt: t,
        ),
      );

  Future<Map<String, String?>> gearOn(String diveId) async {
    final rows = await (db.select(
      db.diveEquipment,
    )..where((r) => r.diveId.equals(diveId))).get();
    return {for (final r in rows) r.equipmentId: r.viaSetId};
  }

  setUp(() async {
    db = await setUpTestDatabase();
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'd1',
            name: 'd1',
            createdAt: t,
            updatedAt: t,
          ),
        );
    for (final id in ['bp', 'reg', 'cam']) {
      await gear(id);
    }
    await gear('pc', type: 'computer');
    await dive('dive1');
  });
  tearDown(tearDownTestDatabase);

  test('membersOfSet includes an included set\'s gear', () async {
    await set('rig', ['bp', 'reg']);
    await set('outer', ['cam'], includes: ['rig']);
    final queries = GearTemplateDiveQueries(db);
    expect(await queries.membersOfSet('outer'), {'bp', 'reg', 'cam'});
    expect(await queries.membersOfSet('rig'), {'bp', 'reg'});
  });

  test('bulkAddEquipmentSets adds included gear under the outer set', () async {
    await set('rig', ['bp', 'reg']);
    await set('outer', ['cam'], includes: ['rig']);
    final changed = await DiveRepository().bulkAddEquipmentSets(
      ['dive1'],
      ['outer'],
    );
    expect(changed, ['dive1']);
    expect(await gearOn('dive1'), {
      'bp': 'outer',
      'reg': 'outer',
      'cam': 'outer',
    });
  });

  test('a set with only included gear still applies in bulk', () async {
    await set('rig', ['bp']);
    await set('outer', const [], includes: ['rig']);
    await DiveRepository().bulkAddEquipmentSets(['dive1'], ['outer']);
    expect(await gearOn('dive1'), {'bp': 'outer'});
  });

  test('the default set applies its included gear on a new dive', () async {
    await set('rig', ['bp', 'reg']);
    await set('outer', ['cam'], includes: ['rig'], isDefault: true);
    final applied = await DiveEquipmentDefaulter().applyDefaultEquipmentIfEmpty(
      diveId: 'dive1',
      diverId: 'd1',
      divePoints: const [],
    );
    expect(applied, isTrue);
    expect((await gearOn('dive1')).keys.toSet(), {'bp', 'reg', 'cam'});
    expect((await gearOn('dive1')).values.toSet(), {'outer'});
  });

  test('a set that reaches the computer through an included set '
      'is applied on import', () async {
    await set('rig', ['bp', 'pc']);
    await set('outer', ['cam'], includes: ['rig'], autoApply: true);
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion.insert(
            id: 'computer1',
            name: 'Teric',
            equipmentId: const Value('pc'),
            createdAt: t,
            updatedAt: t,
          ),
        );
    await db.customStatement(
      'INSERT INTO dive_data_sources (id, dive_id, computer_id, is_primary, '
      'imported_at, created_at) VALUES (?, ?, ?, 1, 1, 1)',
      ['src1', 'dive1', 'computer1'],
    );

    final applied = await EquipmentSetForComputerLinker()
        .linkComputerSetsForDive(diveId: 'dive1');
    expect(applied, isTrue);
    expect((await gearOn('dive1')).keys.toSet(), {'bp', 'pc', 'cam'});
    expect((await gearOn('dive1')).values.toSet(), {'outer'});
  });
}
