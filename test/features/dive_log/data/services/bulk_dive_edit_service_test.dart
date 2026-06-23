import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart'
    show BuddyRole, TankMaterial, WeightType;
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart'
    as domain;
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/bulk_dive_edit_service.dart';
import 'package:submersion/features/dive_log/domain/entities/bulk_edit_request.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart'
    as domain;
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart'
    as domain;

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late BulkDiveEditService service;
  late DiveRepository diveRepo;
  late BuddyRepository buddyRepo;
  late SpeciesRepository speciesRepo;

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement('PRAGMA foreign_keys = OFF');
    diveRepo = DiveRepository();
    buddyRepo = BuddyRepository();
    speciesRepo = SpeciesRepository();
    service = BulkDiveEditService(diveRepo, buddyRepo, speciesRepo);
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> seed(String id) => diveRepo.createDive(
    domain.Dive(id: id, dateTime: DateTime(2026, 1, 1), notes: ''),
  );

  // Buddy snapshot capture JOINs the buddies catalog, so links need a catalog
  // row to survive a capture/restore round-trip.
  Future<void> seedBuddy(String id) => db
      .into(db.buddies)
      .insert(
        BuddiesCompanion(
          id: Value(id),
          name: Value(id),
          createdAt: const Value(0),
          updatedAt: const Value(0),
        ),
      );

  domain.BuddyWithRole bwr(String id) => domain.BuddyWithRole(
    buddy: domain.Buddy(
      id: id,
      name: id,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    ),
    role: BuddyRole.buddy,
  );
  domain.DiveTank tank(String name, {TankMaterial? material}) =>
      domain.DiveTank(id: '', name: name, material: material);
  domain.DiveWeight weight(double kg) => domain.DiveWeight(
    id: '',
    diveId: '',
    weightType: WeightType.belt,
    amountKg: kg,
  );
  domain.Sighting sighting(String speciesId) => domain.Sighting(
    id: '',
    diveId: '',
    speciesId: speciesId,
    speciesName: '',
  );

  Future<List<String>> tagsOf(String d) async => (await (db.select(
    db.diveTags,
  )..where((t) => t.diveId.equals(d))).get()).map((r) => r.tagId).toList();
  Future<List<String>> equipOf(String d) async =>
      (await (db.select(
            db.diveEquipment,
          )..where((t) => t.diveId.equals(d))).get())
          .map((r) => r.equipmentId)
          .toList();
  Future<List<String>> buddiesOf(String d) async => (await (db.select(
    db.diveBuddies,
  )..where((t) => t.diveId.equals(d))).get()).map((r) => r.buddyId).toList();
  Future<List<String?>> tanksOf(String d) async => (await (db.select(
    db.diveTanks,
  )..where((t) => t.diveId.equals(d))).get()).map((r) => r.tankName).toList();
  Future<List<double>> weightsOf(String d) async => (await (db.select(
    db.diveWeights,
  )..where((t) => t.diveId.equals(d))).get()).map((r) => r.amountKg).toList();
  Future<List<String>> sightingsOf(String d) async => (await (db.select(
    db.sightings,
  )..where((t) => t.diveId.equals(d))).get()).map((r) => r.speciesId).toList();

  test(
    'apply writes scalars + notes-append + a tag op and returns a snapshot',
    () async {
      await seed('d1');
      await seed('d2');

      final snap = await service.apply(
        const BulkEditRequest(
          diveIds: ['d1', 'd2'],
          scalars: DivesCompanion(rating: Value(4)),
          notesAppend: ' trip',
          ops: [
            TagsOp(mode: BulkCollectionMode.replace, tagIds: ['t1']),
          ],
        ),
      );

      final r1 = await (db.select(
        db.dives,
      )..where((t) => t.id.equals('d1'))).getSingle();
      expect(r1.rating, 4);
      expect(r1.notes, ' trip');
      expect((await tagsOf('d1')).single, 't1');
      expect(snap.priorDiveRows.length, 2);
      expect(snap.priorTagIds, isNotNull);
    },
  );

  test('undo restores prior scalar values and tag membership', () async {
    await seed('d1');
    await diveRepo.bulkUpdateFields([
      'd1',
    ], const DivesCompanion(rating: Value(2)));
    await diveRepo.bulkReplaceTags(['d1'], ['orig']);

    final snap = await service.apply(
      const BulkEditRequest(
        diveIds: ['d1'],
        scalars: DivesCompanion(rating: Value(9)),
        ops: [
          TagsOp(mode: BulkCollectionMode.replace, tagIds: ['new']),
        ],
      ),
    );

    await service.undo(snap);

    final r = await (db.select(
      db.dives,
    )..where((t) => t.id.equals('d1'))).getSingle();
    expect(r.rating, 2); // restored
    expect((await tagsOf('d1')).single, 'orig'); // restored
  });

  test('apply+undo round-trips every collection type (replace)', () async {
    await seed('d1');
    await diveRepo.bulkReplaceTags(['d1'], ['origTag']);
    await diveRepo.bulkAddEquipment(['d1'], ['origEq']);
    await seedBuddy('origBuddy');
    await buddyRepo.bulkAddBuddies(['d1'], [bwr('origBuddy')]);
    await diveRepo.bulkAddTank([
      'd1',
    ], tank('OrigTank', material: TankMaterial.steel));
    await diveRepo.bulkAddWeights(['d1'], [weight(3)]);
    await speciesRepo.bulkAddSightings(['d1'], [sighting('origFish')]);

    final snap = await service.apply(
      BulkEditRequest(
        diveIds: const ['d1'],
        ops: [
          const TagsOp(mode: BulkCollectionMode.replace, tagIds: ['newTag']),
          const EquipmentOp(
            mode: BulkCollectionMode.replace,
            equipmentIds: ['newEq'],
          ),
          BuddiesOp(
            mode: BulkCollectionMode.replace,
            buddies: [bwr('newBuddy')],
          ),
          TanksOp(mode: BulkCollectionMode.replace, tanks: [tank('NewTank')]),
          WeightsOp(mode: BulkCollectionMode.replace, weights: [weight(9)]),
          SightingsOp(
            mode: BulkCollectionMode.replace,
            sightings: [sighting('newFish')],
          ),
        ],
      ),
    );

    expect((await tagsOf('d1')).single, 'newTag');
    expect((await equipOf('d1')).single, 'newEq');
    expect((await buddiesOf('d1')).single, 'newBuddy');
    expect((await tanksOf('d1')).single, 'NewTank');
    expect((await weightsOf('d1')).single, 9);
    expect((await sightingsOf('d1')).single, 'newFish');

    await service.undo(snap);

    expect((await tagsOf('d1')).single, 'origTag');
    expect((await equipOf('d1')).single, 'origEq');
    expect((await buddiesOf('d1')).single, 'origBuddy');
    expect((await tanksOf('d1')).single, 'OrigTank');
    expect((await weightsOf('d1')).single, 3);
    expect((await sightingsOf('d1')).single, 'origFish');
  });

  test('apply handles add and remove modes across collections', () async {
    await seed('d1');
    await service.apply(
      BulkEditRequest(
        diveIds: const ['d1'],
        ops: [
          const TagsOp(mode: BulkCollectionMode.add, tagIds: ['t1', 't2']),
          const EquipmentOp(mode: BulkCollectionMode.add, equipmentIds: ['e1']),
          BuddiesOp(mode: BulkCollectionMode.add, buddies: [bwr('b1')]),
          TanksOp(mode: BulkCollectionMode.add, tanks: [tank('AL80')]),
          WeightsOp(mode: BulkCollectionMode.add, weights: [weight(4)]),
          SightingsOp(
            mode: BulkCollectionMode.add,
            sightings: [sighting('fish')],
          ),
        ],
      ),
    );
    expect((await tagsOf('d1')).toSet(), {'t1', 't2'});
    expect((await tanksOf('d1')).length, 1);
    expect((await weightsOf('d1')).single, 4);
    expect((await sightingsOf('d1')).single, 'fish');

    await service.apply(
      BulkEditRequest(
        diveIds: const ['d1'],
        ops: [
          const TagsOp(mode: BulkCollectionMode.remove, tagIds: ['t1']),
          const EquipmentOp(
            mode: BulkCollectionMode.remove,
            equipmentIds: ['e1'],
          ),
          BuddiesOp(mode: BulkCollectionMode.remove, buddies: [bwr('b1')]),
        ],
      ),
    );
    expect((await tagsOf('d1')).toSet(), {'t2'});
    expect(await equipOf('d1'), isEmpty);
    expect(await buddiesOf('d1'), isEmpty);
  });

  test(
    'apply with no dives returns an empty snapshot; undo is a no-op',
    () async {
      final snap = await service.apply(const BulkEditRequest(diveIds: []));
      expect(snap.priorDiveRows, isEmpty);
      await service.undo(snap); // must not throw
    },
  );

  test('owned-collection ops reject the remove mode', () async {
    await seed('d1');
    await expectLater(
      service.apply(
        BulkEditRequest(
          diveIds: const ['d1'],
          ops: [
            TanksOp(mode: BulkCollectionMode.remove, tanks: [tank('x')]),
          ],
        ),
      ),
      throwsUnsupportedError,
    );
    await expectLater(
      service.apply(
        BulkEditRequest(
          diveIds: const ['d1'],
          ops: [
            WeightsOp(mode: BulkCollectionMode.remove, weights: [weight(1)]),
          ],
        ),
      ),
      throwsUnsupportedError,
    );
    await expectLater(
      service.apply(
        BulkEditRequest(
          diveIds: const ['d1'],
          ops: [
            SightingsOp(
              mode: BulkCollectionMode.remove,
              sightings: [sighting('x')],
            ),
          ],
        ),
      ),
      throwsUnsupportedError,
    );
  });
}
