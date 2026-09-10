import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/equipment/domain/entities/gear_history_rewrite.dart';
import 'package:submersion/features/equipment/domain/entities/gear_provenance.dart';

import '../../../../helpers/test_database.dart';

/// "Also update N past dives" (issue #1487): every dive carrying the
/// assembly is rewritten through the diff writer and re-stamped; a dive
/// without it is not touched at all.
void main() {
  late AppDatabase db;
  late DiveRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = DiveRepository();
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'd1',
            name: 'd1',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    for (final id in ['reg', 'hose', 'first', 'newhose', 'mask']) {
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: id,
              name: id,
              type: 'regulator',
              createdAt: 1,
              updatedAt: 1,
              diverId: const Value('d1'),
            ),
          );
    }
    await db
        .into(db.equipmentSets)
        .insert(
          EquipmentSetsCompanion.insert(
            id: 'winter',
            name: 'Winter',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    // Two dives carry the assembly, one does not.
    for (final id in ['a', 'b', 'c']) {
      await repo.createDive(
        domain.Dive(id: id, dateTime: DateTime(2026, 1, 1)),
      );
    }
    await repo.replaceGearRows('a', const [
      GearProvenance(equipmentId: 'reg', viaSetId: 'winter'),
      GearProvenance(
        equipmentId: 'hose',
        viaEquipmentId: 'reg',
        viaSetId: 'winter',
      ),
    ]);
    await repo.replaceGearRows('b', const [
      GearProvenance(equipmentId: 'reg'),
      GearProvenance(equipmentId: 'hose', viaEquipmentId: 'reg'),
      GearProvenance(equipmentId: 'mask'),
    ]);
    await repo.replaceGearRows('c', const [
      GearProvenance(equipmentId: 'mask'),
    ]);
  });

  tearDown(tearDownTestDatabase);

  Future<Map<String, DiveEquipmentData>> rowsOf(String diveId) async => {
    for (final r in await (db.select(
      db.diveEquipment,
    )..where((t) => t.diveId.equals(diveId))).get())
      r.equipmentId: r,
  };

  Future<int> updatedAtOf(String diveId) async => (await (db.select(
    db.dives,
  )..where((t) => t.id.equals(diveId))).getSingle()).updatedAt;

  test('diveIdsWithEquipment lists the dives that carry the item', () async {
    expect(await repo.diveIdsWithEquipment('reg'), unorderedEquals(['a', 'b']));
    expect(await repo.diveIdsWithEquipment('newhose'), isEmpty);
  });

  test(
    'an added part lands on every dive with the assembly, tagged with its set',
    () async {
      final before = await updatedAtOf('c');
      final touched = await repo.rewriteAssemblyOnPastDives('reg', const [
        GearPartAdded('first'),
      ]);
      expect(touched, 2);
      final a = await rowsOf('a');
      expect(a['first']!.viaEquipmentId, 'reg');
      expect(a['first']!.viaSetId, 'winter');
      expect((await rowsOf('b'))['first']!.viaSetId, isNull);
      expect((await rowsOf('c')).keys, ['mask']);
      expect(await updatedAtOf('c'), before);
    },
  );

  test('a removed part leaves every dive and tombstones the rows', () async {
    await repo.rewriteAssemblyOnPastDives('reg', const [
      GearPartRemoved('hose'),
    ]);
    expect((await rowsOf('a')).keys, ['reg']);
    expect((await rowsOf('b')).keys, unorderedEquals(['reg', 'mask']));
    final tombstones = [
      for (final t in await db.select(db.deletionLog).get())
        if (t.entityType == 'diveEquipment') t.recordId,
    ];
    expect(tombstones, unorderedEquals(['a|hose', 'b|hose']));
  });

  test(
    'a replaced part is re-keyed and each touched dive is re-stamped',
    () async {
      final before = await updatedAtOf('a');
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await repo.rewriteAssemblyOnPastDives('reg', const [
        GearPartReplaced(oldPartId: 'hose', newPartId: 'newhose'),
      ]);
      final a = await rowsOf('a');
      expect(a.keys, unorderedEquals(['reg', 'newhose']));
      expect(a['newhose']!.viaEquipmentId, 'reg');
      expect(a['newhose']!.viaSetId, 'winter');
      expect(await updatedAtOf('a'), greaterThan(before));
    },
  );

  test('a rewrite that changes nothing touches no dive', () async {
    final before = await updatedAtOf('a');
    final touched = await repo.rewriteAssemblyOnPastDives('reg', const [
      GearPartRemoved('first'),
    ]);
    expect(touched, 0);
    expect(await updatedAtOf('a'), before);
  });

  test('a batch applies every rewrite in one pass over the dives', () async {
    final touched = await repo.rewriteAssemblyOnPastDives('reg', const [
      GearPartAdded('first'),
      GearPartAdded('newhose'),
      GearPartRemoved('hose'),
    ]);
    expect(touched, 2);
    final a = await rowsOf('a');
    expect(a.keys, unorderedEquals(['reg', 'first', 'newhose']));
    expect(a['first']!.viaEquipmentId, 'reg');
    expect(a['newhose']!.viaSetId, 'winter');
    expect(
      (await rowsOf('b')).keys,
      unorderedEquals(['reg', 'first', 'newhose', 'mask']),
    );
    // The removed part left one tombstone per dive, not one per rewrite.
    final tombstones = [
      for (final t in await db.select(db.deletionLog).get())
        if (t.entityType == 'diveEquipment') t.recordId,
    ];
    expect(tombstones, unorderedEquals(['a|hose', 'b|hose']));
  });

  test('an empty batch touches nothing', () async {
    final before = await updatedAtOf('a');
    expect(await repo.rewriteAssemblyOnPastDives('reg', const []), 0);
    expect(await updatedAtOf('a'), before);
  });
}
