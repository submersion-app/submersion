import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart'
    as weight;
import 'package:submersion/features/equipment/data/repositories/equipment_component_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/equipment/domain/entities/gear_provenance.dart';

import '../../../../helpers/test_database.dart';

/// Provenance on dive_equipment (issue #1487): read on both hydration paths,
/// written by create and the diff update, expanded by the bulk operations.
void main() {
  late AppDatabase db;
  late DiveRepository repo;
  late EquipmentComponentRepository components;

  Future<void> seedEquipment(String id, {bool active = true}) => db
      .into(db.equipment)
      .insert(
        EquipmentCompanion.insert(
          id: id,
          name: id,
          type: 'regulator',
          createdAt: 1,
          updatedAt: 1,
          diverId: const Value('d1'),
          isActive: Value(active),
          status: Value(active ? 'active' : 'retired'),
        ),
      );

  setUp(() async {
    db = await setUpTestDatabase();
    repo = DiveRepository();
    components = EquipmentComponentRepository(
      equipmentRepository: EquipmentRepository(),
    );
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
    for (final id in ['reg', 'first', 'hose', 'fins', 'mask']) {
      await seedEquipment(id);
    }
    await seedEquipment('old-hose', active: false);
    await components.addComponent(parentId: 'reg', componentId: 'first');
    await components.addComponent(parentId: 'reg', componentId: 'hose');
    await components.addComponent(parentId: 'reg', componentId: 'old-hose');
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
  });

  tearDown(tearDownTestDatabase);

  EquipmentItem item(String id) =>
      EquipmentItem(id: id, name: id, type: EquipmentType.regulator);

  Future<Map<String, DiveEquipmentData>> rowsOf(String diveId) async => {
    for (final r in await (db.select(
      db.diveEquipment,
    )..where((t) => t.diveId.equals(diveId))).get())
      r.equipmentId: r,
  };

  Future<Set<String>> pending() async => {
    for (final r in await db.select(db.syncRecords).get())
      if (r.entityType == 'diveEquipment') r.recordId,
  };

  // Issue #1720. updateDive rewrites a dive's children in sequence: weights
  // are deleted and re-inserted, then the gear diff deletes the rows that are
  // no longer wanted and inserts the new ones. With no transaction around it,
  // a throw partway through committed everything before the throw, so a dive
  // was left holding a strict PREFIX of the diver's gear -- and the next read
  // reported that truncation as the truth.
  test(
    'a failed update leaves the dive\'s gear and weights untouched',
    () async {
      await repo.createDive(
        domain.Dive(
          id: 'dv',
          dateTime: DateTime(2026, 1, 1),
          gear: looseGear([item('fins'), item('mask')]),
          weights: const [
            weight.DiveWeight(
              id: 'w1',
              diveId: 'dv',
              weightType: WeightType.belt,
              amountKg: 4,
            ),
          ],
        ),
      );
      expect((await rowsOf('dv')).keys, unorderedEquals(['fins', 'mask']));

      // 'ghost' is not in the equipment table, so its junction insert violates
      // the foreign key -- the same shape as a link whose gear item has gone.
      // The delete of 'fins' and the weight rewrite both run before it.
      await expectLater(
        repo.updateDive(
          domain.Dive(
            id: 'dv',
            dateTime: DateTime(2026, 1, 1),
            gear: looseGear([item('mask'), item('ghost')]),
            weights: const [],
          ),
        ),
        throwsA(anything),
      );

      expect(
        (await rowsOf('dv')).keys,
        unorderedEquals(['fins', 'mask']),
        reason: 'the rolled-back update must not cost the diver their gear',
      );
      final weights = await (db.select(
        db.diveWeights,
      )..where((t) => t.diveId.equals('dv'))).get();
      expect(weights.map((w) => w.id), [
        'w1',
      ], reason: 'every child the update touched rolls back together');
    },
  );

  test('createDive writes provenance and marks each link pending', () async {
    await repo.createDive(
      domain.Dive(
        id: 'dv',
        dateTime: DateTime(2026, 1, 1),
        gear: [
          GearLink(item: item('reg'), viaSetId: 'winter'),
          GearLink(
            item: item('hose'),
            viaEquipmentId: 'reg',
            viaSetId: 'winter',
          ),
          GearLink(item: item('mask')),
        ],
      ),
    );
    final rows = await rowsOf('dv');
    expect(rows['reg']!.viaSetId, 'winter');
    expect(rows['hose']!.viaEquipmentId, 'reg');
    expect(rows['mask']!.viaEquipmentId, isNull);
    expect(await pending(), containsAll(['dv|reg', 'dv|hose', 'dv|mask']));

    final read = await repo.getDiveById('dv');
    expect(
      read!.gear.firstWhere((g) => g.item.id == 'hose').viaEquipmentId,
      'reg',
    );
    expect(read.gear.firstWhere((g) => g.item.id == 'reg').viaSetId, 'winter');
  });

  test('getAllDives hydrates provenance too', () async {
    await repo.createDive(
      domain.Dive(
        id: 'dv',
        dateTime: DateTime(2026, 1, 1),
        gear: [
          GearLink(item: item('reg')),
          GearLink(item: item('hose'), viaEquipmentId: 'reg'),
        ],
      ),
    );
    final all = await repo.getAllDives();
    expect(
      all.single.gear.firstWhere((g) => g.item.id == 'hose').viaEquipmentId,
      'reg',
    );
  });

  test(
    'updateDive diffs: changed provenance updated, added inserted, removed tombstoned',
    () async {
      await repo.createDive(
        domain.Dive(
          id: 'dv',
          dateTime: DateTime(2026, 1, 1),
          gear: [
            GearLink(item: item('reg')),
            GearLink(item: item('hose'), viaEquipmentId: 'reg'),
            GearLink(item: item('mask')),
          ],
        ),
      );
      final before = await repo.getDiveById('dv');
      await repo.updateDive(
        before!.copyWith(
          gear: [
            GearLink(item: item('reg')),
            GearLink(
              item: item('hose'),
              viaEquipmentId: 'reg',
              viaSetId: 'winter',
            ),
            GearLink(item: item('fins')),
          ],
        ),
      );
      final rows = await rowsOf('dv');
      expect(rows.keys, unorderedEquals(['reg', 'hose', 'fins']));
      expect(rows['hose']!.viaSetId, 'winter');
      final tombstones = [
        for (final t in await db.select(db.deletionLog).get())
          if (t.entityType == 'diveEquipment') t.recordId,
      ];
      expect(tombstones, ['dv|mask']);
    },
  );

  test(
    'bulkAddEquipment expands an assembly, skips a retired part, tags the set',
    () async {
      await repo.createDive(
        domain.Dive(id: 'dv', dateTime: DateTime(2026, 1, 1)),
      );
      await repo.bulkAddEquipment(['dv'], ['reg'], viaSetId: 'winter');
      final rows = await rowsOf('dv');
      expect(rows.keys, unorderedEquals(['reg', 'first', 'hose']));
      expect(rows['first']!.viaEquipmentId, 'reg');
      expect(rows['first']!.viaSetId, 'winter');
      expect(rows['reg']!.viaSetId, 'winter');
    },
  );

  test('bulkRemoveEquipment drops the whole subtree', () async {
    await repo.createDive(
      domain.Dive(id: 'dv', dateTime: DateTime(2026, 1, 1)),
    );
    await repo.bulkAddEquipment(['dv'], ['reg', 'mask']);
    await repo.bulkRemoveEquipment(['dv'], ['reg']);
    expect((await rowsOf('dv')).keys, ['mask']);
  });

  test(
    'replaceGearRows writes exactly the given rows with provenance',
    () async {
      await repo.createDive(
        domain.Dive(id: 'dv', dateTime: DateTime(2026, 1, 1)),
      );
      await repo.bulkAddEquipment(['dv'], ['reg']);
      await repo.replaceGearRows('dv', const [
        GearProvenance(equipmentId: 'mask'),
        GearProvenance(
          equipmentId: 'hose',
          viaEquipmentId: 'mask',
          viaSetId: 'winter',
        ),
      ]);
      final rows = await rowsOf('dv');
      expect(rows.keys, unorderedEquals(['mask', 'hose']));
      expect(rows['hose']!.viaEquipmentId, 'mask');
    },
  );
}
