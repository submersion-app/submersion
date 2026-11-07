import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/equipment/domain/entities/gear_history_rewrite.dart';
import 'package:submersion/features/equipment/domain/entities/gear_provenance.dart';
import 'package:submersion/features/equipment/domain/entities/set_history_rewrite.dart';

import '../../../../helpers/test_database.dart';

/// "Also update N dives" for an equipment set (issue #4283), and the count
/// and rewrite of an assembly unified on the same dives: planned dives
/// always follow a template change, logged dives only when asked, and the
/// count names the logged dives a rewrite would visit.
void main() {
  late AppDatabase db;
  late DiveRepository repo;

  Future<void> seedItem(String id, {String diverId = 'd1'}) => db
      .into(db.equipment)
      .insert(
        EquipmentCompanion.insert(
          id: id,
          name: id,
          type: 'bcd',
          createdAt: 1,
          updatedAt: 1,
          diverId: Value(diverId),
        ),
      );

  setUp(() async {
    db = await setUpTestDatabase();
    repo = DiveRepository();
    for (final id in ['d1', 'd2']) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: id,
              name: id,
              createdAt: 1,
              updatedAt: 1,
            ),
          );
    }
    for (final id in ['bcd', 'fins', 'mask', 'reg', 'hose']) {
      await seedItem(id);
    }
    // Owned by the other diver and not shared: applying the set skips it.
    await seedItem('theirs', diverId: 'd2');
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
    // logged: a carries the set, c does not; planned: p carries the set.
    for (final (id, planned) in [('a', false), ('c', false), ('p', true)]) {
      await repo.createDive(
        domain.Dive(
          id: id,
          dateTime: DateTime(2026, 1, 1),
          diverId: 'd1',
          isPlanned: planned,
        ),
      );
    }
    for (final id in ['a', 'p']) {
      await repo.replaceGearRows(id, const [
        GearProvenance(equipmentId: 'bcd', viaSetId: 'winter'),
        GearProvenance(equipmentId: 'reg'),
        GearProvenance(equipmentId: 'mask'),
      ]);
    }
    await repo.replaceGearRows('c', const [
      GearProvenance(equipmentId: 'bcd'),
      GearProvenance(equipmentId: 'reg'),
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

  group('sets', () {
    test('the count names the logged dives that carry the set', () async {
      expect(await repo.countLoggedDivesWithSet('winter'), 1);
      expect(await repo.countLoggedDivesWithSet('summer'), 0);
    });

    test('from now on: only the planned dive follows the change', () async {
      final touched = await repo.rewriteSetOnDives('winter', const [
        SetItemAdded('fins'),
      ], alsoLogged: false);
      expect(touched, 1);
      expect((await rowsOf('p'))['fins']!.viaSetId, 'winter');
      expect((await rowsOf('a')).containsKey('fins'), isFalse);
    });

    test('also logged: every dive with the set, none without', () async {
      final before = await updatedAtOf('c');
      final touched = await repo.rewriteSetOnDives('winter', const [
        SetItemAdded('fins'),
      ], alsoLogged: true);
      expect(touched, 2);
      expect((await rowsOf('a'))['fins']!.viaSetId, 'winter');
      expect((await rowsOf('p'))['fins']!.viaSetId, 'winter');
      expect((await rowsOf('c')).containsKey('fins'), isFalse);
      expect(await updatedAtOf('c'), before);
    });

    test('a hand-added row is adopted, not duplicated', () async {
      await repo.rewriteSetOnDives('winter', const [
        SetItemAdded('mask'),
      ], alsoLogged: true);
      expect((await rowsOf('a'))['mask']!.viaSetId, 'winter');
    });

    test('gear the dive diver may not use is not added', () async {
      final touched = await repo.rewriteSetOnDives('winter', const [
        SetItemAdded('theirs'),
      ], alsoLogged: true);
      expect(touched, 0);
      expect((await rowsOf('a')).containsKey('theirs'), isFalse);
    });

    test('a removed member leaves the set dives, hand rows stay', () async {
      await repo.rewriteSetOnDives('winter', const [
        SetItemRemoved('bcd'),
        SetItemRemoved('reg'),
      ], alsoLogged: true);
      expect((await rowsOf('a')).keys, unorderedEquals(['reg', 'mask']));
      expect((await rowsOf('p')).keys, unorderedEquals(['reg', 'mask']));
      expect((await rowsOf('c')).keys, unorderedEquals(['bcd', 'reg']));
      final tombstones = [
        for (final t in await db.select(db.deletionLog).get())
          if (t.entityType == 'diveEquipment') t.recordId,
      ];
      expect(tombstones, unorderedEquals(['a|bcd', 'p|bcd']));
    });

    test('an empty batch touches nothing', () async {
      final before = await updatedAtOf('p');
      expect(
        await repo.rewriteSetOnDives('winter', const [], alsoLogged: true),
        0,
      );
      expect(await updatedAtOf('p'), before);
    });
  });

  group('assemblies', () {
    test('the count names the logged dives the rewrite visits', () async {
      // a and c are logged and carry reg; p is planned and not counted.
      expect(await repo.countLoggedDivesWithAssembly('reg'), 2);
      expect(await repo.countLoggedDivesWithAssembly('fins'), 0);
    });

    test('from now on: only the planned dive follows the change', () async {
      final touched = await repo.rewriteAssemblyOnDives('reg', const [
        GearPartAdded('hose'),
      ], alsoLogged: false);
      expect(touched, 1);
      expect((await rowsOf('p'))['hose']!.viaEquipmentId, 'reg');
      expect((await rowsOf('a')).containsKey('hose'), isFalse);
      expect((await rowsOf('c')).containsKey('hose'), isFalse);
    });

    test('also logged: every dive with the assembly', () async {
      final touched = await repo.rewriteAssemblyOnDives('reg', const [
        GearPartAdded('hose'),
      ], alsoLogged: true);
      expect(touched, 3);
    });
  });
}
