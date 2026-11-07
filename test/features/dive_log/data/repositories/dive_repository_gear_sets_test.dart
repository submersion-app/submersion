import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/equipment/data/repositories/equipment_component_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';

import '../../../../helpers/test_database.dart';

/// Whole equipment sets on many dives at once (#4284): the gear arrives
/// tagged with its set, and removing a set takes only what it brought.
void main() {
  late AppDatabase db;
  late DiveRepository repo;

  Future<void> seedEquipment(String id) => db
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

  Future<void> seedSet(String id, List<String> items) async {
    await db
        .into(db.equipmentSets)
        .insert(
          EquipmentSetsCompanion.insert(
            id: id,
            name: id,
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    for (final item in items) {
      await db
          .into(db.equipmentSetItems)
          .insert(
            EquipmentSetItemsCompanion.insert(setId: id, equipmentId: item),
          );
    }
  }

  Future<Map<String, DiveEquipmentData>> rowsOf(String diveId) async => {
    for (final r in await (db.select(
      db.diveEquipment,
    )..where((t) => t.diveId.equals(diveId))).get())
      r.equipmentId: r,
  };

  Future<int> updatedAtOf(String diveId) async => (await (db.select(
    db.dives,
  )..where((t) => t.id.equals(diveId))).getSingle()).updatedAt;

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
    for (final id in ['reg', 'first', 'bcd', 'fins', 'lamp']) {
      await seedEquipment(id);
    }
    await EquipmentComponentRepository(
      equipmentRepository: EquipmentRepository(),
    ).addComponent(parentId: 'reg', componentId: 'first');
    await seedSet('warm', ['reg', 'bcd']);
    await seedSet('photo', ['bcd', 'fins']);
    await seedSet('empty', []);
    for (final id in ['a', 'b']) {
      await repo.createDive(
        domain.Dive(id: id, dateTime: DateTime(2026, 1, 1)),
      );
    }
  });

  tearDown(tearDownTestDatabase);

  group('bulkAddEquipmentSets', () {
    test('adds each set item and its parts, tagged with the set', () async {
      final changed = await repo.bulkAddEquipmentSets(['a', 'b'], ['warm']);

      expect(changed, unorderedEquals(['a', 'b']));
      final rows = await rowsOf('a');
      expect(rows.keys, unorderedEquals(['reg', 'first', 'bcd']));
      expect(rows.values.map((r) => r.viaSetId).toSet(), {'warm'});
      expect(rows['first']!.viaEquipmentId, 'reg');
    });

    test('the first set wins an item two sets share', () async {
      await repo.bulkAddEquipmentSets(['a'], ['warm', 'photo']);

      final rows = await rowsOf('a');
      expect(rows['bcd']!.viaSetId, 'warm');
      expect(rows['fins']!.viaSetId, 'photo');
    });

    test('an item already from another set keeps that set', () async {
      await repo.bulkAddEquipmentSets(['a'], ['photo']);
      await repo.bulkAddEquipmentSets(['a'], ['warm']);

      expect((await rowsOf('a'))['bcd']!.viaSetId, 'photo');
    });

    test('an item added by hand takes on the set', () async {
      await repo.bulkAddEquipment(['a'], ['bcd']);

      await repo.bulkAddEquipmentSets(['a'], ['warm']);

      expect((await rowsOf('a'))['bcd']!.viaSetId, 'warm');
    });

    test('reports and writes only the dives that change', () async {
      await repo.bulkAddEquipmentSets(['a'], ['warm']);
      final stamp = await updatedAtOf('a');

      final changed = await repo.bulkAddEquipmentSets(['a', 'b'], ['warm']);

      expect(changed, ['b']);
      expect(await updatedAtOf('a'), stamp);
    });

    test('an empty set or no set changes nothing', () async {
      expect(await repo.bulkAddEquipmentSets(['a'], ['empty']), isEmpty);
      expect(await repo.bulkAddEquipmentSets(['a'], const []), isEmpty);
      expect(await repo.bulkAddEquipmentSets(const [], ['warm']), isEmpty);
      expect(await rowsOf('a'), isEmpty);
    });
  });

  group('bulkRemoveEquipmentSets', () {
    test('removes what the set brought, parts included', () async {
      await repo.bulkAddEquipmentSets(['a'], ['warm', 'photo']);

      final changed = await repo.bulkRemoveEquipmentSets(['a'], ['warm']);

      expect(changed, ['a']);
      expect((await rowsOf('a')).keys, ['fins']);
    });

    test('keeps gear added by hand, even when the set holds it', () async {
      await repo.bulkAddEquipment(['a'], ['lamp', 'fins']);
      await repo.bulkAddEquipmentSets(['a'], ['warm']);

      await repo.bulkRemoveEquipmentSets(['a'], ['warm', 'photo']);

      expect((await rowsOf('a')).keys, unorderedEquals(['lamp', 'fins']));
    });

    test('a part attached through a removed item goes with it', () async {
      await repo.bulkAddEquipment(['a'], ['first']);
      await repo.bulkAddEquipmentSets(['a'], ['warm']);

      await repo.bulkRemoveEquipmentSets(['a'], ['warm']);

      expect(await rowsOf('a'), isEmpty);
    });

    test('a dive without the set is neither reported nor written', () async {
      await repo.bulkAddEquipmentSets(['a'], ['warm']);
      final stamp = await updatedAtOf('b');

      final changed = await repo.bulkRemoveEquipmentSets(['a', 'b'], ['warm']);

      expect(changed, ['a']);
      expect(await updatedAtOf('b'), stamp);
    });
  });
}
