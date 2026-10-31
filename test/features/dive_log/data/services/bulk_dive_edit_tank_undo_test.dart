import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';
import 'package:submersion/features/dive_log/data/services/bulk_dive_edit_service.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';
import 'package:submersion/features/dive_log/domain/entities/bulk_edit_request.dart';
import 'package:submersion/features/dive_log/domain/entities/bulk_edit_snapshot.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart'
    as domain_trip;

import '../../../../helpers/test_database.dart';

/// Undoing a bulk tank edit, with foreign keys on: the cascades from a tank to
/// its recorded children are the whole of issue #3929.
void main() {
  late AppDatabase db;
  late BulkDiveEditService service;
  late DiveRepository diveRepo;

  setUp(() async {
    db = await setUpTestDatabase();
    diveRepo = DiveRepository();
    service = BulkDiveEditService(
      diveRepo,
      BuddyRepository(),
      SpeciesRepository(),
    );
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> seedDive(String id) => diveRepo.createDive(
    domain.Dive(id: id, dateTime: DateTime(2026, 1, 1), notes: ''),
  );

  domain.DiveTank template(String name) =>
      domain.DiveTank(id: '', name: name, volume: 11.1);

  Future<List<DiveTank>> tanksOf(String diveId) =>
      (db.select(db.diveTanks)
            ..where((t) => t.diveId.equals(diveId))
            ..orderBy([(t) => OrderingTerm(expression: t.tankOrder)]))
          .get();

  Future<List<TankPressureSeriesRow>> seriesOf(String diveId) => (db.select(
    db.tankPressureSeries,
  )..where((t) => t.diveId.equals(diveId))).get();

  Future<List<GasSwitche>> switchesOf(String diveId) =>
      (db.select(db.gasSwitches)..where((t) => t.diveId.equals(diveId))).get();

  /// A dive with one tank that recorded a pressure series and a gas switch.
  Future<DiveTank> seedRecordedDive(String diveId) async {
    await seedDive(diveId);
    await diveRepo.bulkAddTank([diveId], template('Recorded $diveId'));
    final tank = (await tanksOf(diveId)).single;
    await TankPressureSeriesRepository().insertSeries(
      diveId: diveId,
      tankId: tank.id,
      samples: const [
        TankPressureSample(timestamp: 0, pressure: 200.0),
        TankPressureSample(timestamp: 60, pressure: 180.0),
      ],
    );
    await db
        .into(db.gasSwitches)
        .insert(
          GasSwitchesCompanion(
            id: Value('switch-$diveId'),
            diveId: Value(diveId),
            timestamp: const Value(120),
            tankId: Value(tank.id),
            depth: const Value(21.0),
            createdAt: const Value(1),
          ),
        );
    return tank;
  }

  Future<BulkEditSnapshot> applyTanks(
    List<String> diveIds,
    BulkCollectionMode mode, {
    bool onlyIfEmpty = false,
  }) => service.apply(
    BulkEditRequest(
      diveIds: diveIds,
      ops: [
        TanksOp(
          mode: mode,
          tanks: [template('Stage')],
          onlyIfEmpty: onlyIfEmpty,
        ),
      ],
    ),
  );

  test('the cascades this file depends on are switched on', () async {
    final tank = await seedRecordedDive('d1');
    await (db.delete(db.diveTanks)..where((t) => t.id.equals(tank.id))).go();
    expect(await seriesOf('d1'), isEmpty);
    expect(await switchesOf('d1'), isEmpty);
  });

  group('undoing an add', () {
    test('removes only the new tank (#3929)', () async {
      final original = await seedRecordedDive('d1');
      final seriesBefore = await seriesOf('d1');
      final switchesBefore = await switchesOf('d1');

      final snap = await applyTanks(['d1'], BulkCollectionMode.add);
      expect(await tanksOf('d1'), hasLength(2));

      await service.undo(snap);

      expect((await tanksOf('d1')).single.id, original.id);
      expect(await seriesOf('d1'), seriesBefore);
      expect(await switchesOf('d1'), switchesBefore);
    });

    test('tombstones the new tank and leaves the original alone', () async {
      final original = await seedRecordedDive('d1');
      final snap = await applyTanks(['d1'], BulkCollectionMode.add);
      final added = (await tanksOf('d1')).last;

      await service.undo(snap);

      final tombstones = (await db.select(db.deletionLog).get())
          .map((d) => d.recordId)
          .toList();
      expect(tombstones, contains(added.id));
      expect(tombstones, isNot(contains(original.id)));
    });

    test('leaves a dive the add skipped untouched', () async {
      final skipped = await seedRecordedDive('d1');
      await seedDive('d2');

      final snap = await applyTanks(
        ['d1', 'd2'],
        BulkCollectionMode.add,
        onlyIfEmpty: true,
      );
      expect(await tanksOf('d2'), hasLength(1));

      await service.undo(snap);

      expect((await tanksOf('d1')).single.id, skipped.id);
      expect(await seriesOf('d1'), hasLength(1));
      expect(await switchesOf('d1'), hasLength(1));
      expect(await tanksOf('d2'), isEmpty);
    });

    test('works across every selected dive', () async {
      final first = await seedRecordedDive('d1');
      final second = await seedRecordedDive('d2');

      final snap = await applyTanks(['d1', 'd2'], BulkCollectionMode.add);
      await service.undo(snap);

      expect((await tanksOf('d1')).single.id, first.id);
      expect((await tanksOf('d2')).single.id, second.id);
      expect(await seriesOf('d1'), hasLength(1));
      expect(await seriesOf('d2'), hasLength(1));
    });

    test('keeps a tank added after the bulk edit', () async {
      await seedRecordedDive('d1');
      final snap = await applyTanks(['d1'], BulkCollectionMode.add);
      await diveRepo.bulkAddTank(['d1'], template('Later'));

      await service.undo(snap);

      expect((await tanksOf('d1')).map((t) => t.tankName), [
        'Recorded d1',
        'Later',
      ]);
    });
  });

  group('undoing a replace', () {
    test('brings back the tank with its id and recorded children', () async {
      final original = await seedRecordedDive('d1');
      final seriesBefore = (await seriesOf('d1')).single;
      final switchBefore = (await switchesOf('d1')).single;

      final snap = await applyTanks(['d1'], BulkCollectionMode.replace);
      expect((await tanksOf('d1')).single.tankName, 'Stage');
      expect(await seriesOf('d1'), isEmpty);

      await service.undo(snap);

      final restored = (await tanksOf('d1')).single;
      expect(restored.id, original.id);
      expect(restored.tankName, original.tankName);
      final series = (await seriesOf('d1')).single;
      expect(series.id, seriesBefore.id);
      expect(series.tankId, original.id);
      expect(series.samples, seriesBefore.samples);
      final gasSwitch = (await switchesOf('d1')).single;
      expect(gasSwitch.id, switchBefore.id);
      expect(gasSwitch.tankId, original.id);
    });

    test('restores every column, even ones a template leaves out', () async {
      final original = await seedRecordedDive('d1');
      await (db.update(
        db.diveTanks,
      )..where((t) => t.id.equals(original.id))).write(
        const DiveTanksCompanion(
          tankOrder: Value(3),
          sharedComputerIds: Value('["c1"]'),
        ),
      );
      final expected = (await tanksOf('d1')).single;

      final snap = await applyTanks(['d1'], BulkCollectionMode.replace);
      await service.undo(snap);

      // The clock alone moves on: an undo is a new edit (#2670).
      expect(
        (await tanksOf('d1')).single.copyWith(hlc: const Value(null)),
        expected.copyWith(hlc: const Value(null)),
      );
    });

    test('clears the tombstone and queues the tank for sync', () async {
      final original = await seedRecordedDive('d1');
      final snap = await applyTanks(['d1'], BulkCollectionMode.replace);
      final template = (await tanksOf('d1')).single;
      Future<List<String>> tombstones() async =>
          (await db.select(db.deletionLog).get())
              .map((d) => d.recordId)
              .toList();
      expect(await tombstones(), contains(original.id));

      await service.undo(snap);

      final after = await tombstones();
      expect(after, isNot(contains(original.id)));
      expect(after, contains(template.id));
      final pending = await db.select(db.syncRecords).get();
      expect(pending.map((r) => r.recordId), contains(original.id));
      expect(pending.map((r) => r.recordId), contains('switch-d1'));
    });

    test('drops links to rows deleted since the edit', () async {
      final original = await seedRecordedDive('d1');
      final series = (await seriesOf('d1')).single;
      Future<void> computer(String id) => db
          .into(db.diveComputers)
          .insert(
            DiveComputersCompanion.insert(
              id: id,
              name: id,
              createdAt: 1,
              updatedAt: 1,
            ),
          );
      await computer('gone-computer');
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: 'gone-gear',
              name: 'Cylinder',
              type: 'tank',
              createdAt: 1,
              updatedAt: 1,
            ),
          );
      await (db.update(
        db.diveTanks,
      )..where((t) => t.id.equals(original.id))).write(
        const DiveTanksCompanion(
          computerId: Value('gone-computer'),
          equipmentId: Value('gone-gear'),
          regulatorEquipmentId: Value('gone-gear'),
        ),
      );
      await (db.update(
        db.tankPressureSeries,
      )..where((t) => t.id.equals(series.id))).write(
        const TankPressureSeriesCompanion(computerId: Value('gone-computer')),
      );
      await (db.update(
        db.gasSwitches,
      )..where((t) => t.id.equals('switch-d1'))).write(
        const GasSwitchesCompanion(computerId: Value('gone-computer')),
      );

      final snap = await applyTanks(['d1'], BulkCollectionMode.replace);
      await (db.delete(
        db.diveComputers,
      )..where((t) => t.id.equals('gone-computer'))).go();
      await (db.delete(
        db.equipment,
      )..where((t) => t.id.equals('gone-gear'))).go();

      await service.undo(snap);

      final tank = (await tanksOf('d1')).single;
      expect(tank.id, original.id);
      expect(tank.computerId, isNull);
      expect(tank.equipmentId, isNull);
      expect(tank.regulatorEquipmentId, isNull);
      expect((await seriesOf('d1')).single.computerId, isNull);
      expect((await switchesOf('d1')).single.computerId, isNull);
    });

    group('a trip cylinder slot', () {
      Future<void> linkTank(DiveTank tank) async {
        final now = DateTime(2026, 1, 1);
        final trip = await TripRepository().createTrip(
          domain_trip.Trip(
            id: '',
            name: 'Bonaire',
            startDate: now,
            endDate: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
        await (db.update(db.dives)..where((t) => t.id.equals(tank.diveId)))
            .write(DivesCompanion(tripId: Value(trip.id)));
        await db
            .into(db.tripCylinders)
            .insert(
              TripCylindersCompanion.insert(
                id: 'slot',
                tripId: trip.id,
                createdAt: 1,
                updatedAt: 1,
              ),
            );
        await (db.update(db.diveTanks)..where((t) => t.id.equals(tank.id)))
            .write(const DiveTanksCompanion(tripCylinderId: Value('slot')));
      }

      test('comes back with the tank', () async {
        await linkTank(await seedRecordedDive('d1'));
        final snap = await applyTanks(['d1'], BulkCollectionMode.replace);

        await service.undo(snap);

        expect((await tanksOf('d1')).single.tripCylinderId, 'slot');
      });

      test('is dropped when it was deleted since the edit', () async {
        await linkTank(await seedRecordedDive('d1'));
        final snap = await applyTanks(['d1'], BulkCollectionMode.replace);
        await db.customStatement(
          "DELETE FROM trip_cylinders WHERE id = 'slot'",
        );

        await service.undo(snap);

        expect((await tanksOf('d1')).single.tripCylinderId, isNull);
      });
    });

    test('a dive that had no tanks goes back to having none', () async {
      await seedDive('d1');
      final snap = await applyTanks(['d1'], BulkCollectionMode.replace);
      expect(await tanksOf('d1'), hasLength(1));

      await service.undo(snap);

      expect(await tanksOf('d1'), isEmpty);
    });
  });
}
