import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/duplicate_cylinder_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';
import 'package:submersion/features/dive_log/domain/entities/tank_shared_computers.dart';

import '../../../../core/database/change_log/change_log_support.dart';
import '../../../../helpers/test_database.dart';

/// Merging a dive's duplicate cylinders into one row (issue #4393).
void main() {
  late AppDatabase db;
  late DuplicateCylinderRepository repository;
  late TankPressureSeriesRepository series;
  const now = 5000;

  Future<void> insertComputer(String id) => db
      .into(db.diveComputers)
      .insert(
        DiveComputersCompanion(
          id: Value(id),
          name: Value(id),
          createdAt: const Value(0),
          updatedAt: const Value(0),
        ),
      );

  Future<void> insertTank(
    String id, {
    String? computerId,
    double o2 = 32,
    double? volume,
    double? workingPressure,
    String? name,
    List<String>? sharedWith,
  }) => db
      .into(db.diveTanks)
      .insert(
        DiveTanksCompanion.insert(
          id: id,
          diveId: 'dive',
          computerId: Value(computerId),
          o2Percent: Value(o2),
          transmitterSerial: const Value('X1'),
          volume: Value(volume),
          workingPressure: Value(workingPressure),
          tankName: Value(name),
          sharedComputerIds: Value(
            sharedWith == null ? null : encodeSharedComputerIds(sharedWith),
          ),
        ),
      );

  Future<String> insertPressure(String tankId, double start) =>
      series.insertSeries(
        diveId: 'dive',
        tankId: tankId,
        computerId: null,
        samples: [
          TankPressureSample(timestamp: 0, pressure: start),
          TankPressureSample(timestamp: 600, pressure: start - 100),
        ],
        now: 1000,
      );

  Future<DiveTank?> tank(String id) => (db.select(
    db.diveTanks,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<bool> merge({({double o2, double he})? mix}) => db.transaction(
    () => repository.mergeInto(
      diveId: 'dive',
      survivorId: 'keep',
      duplicateIds: const ['dup'],
      mix: mix,
      now: now,
    ),
  );

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DuplicateCylinderRepository(database: db);
    series = TankPressureSeriesRepository(database: db);
    await insertDiver(db, 'me');
    await insertDive(db, 'dive', diverId: 'me');
    await insertComputer('dc-a');
    await insertComputer('dc-b');
    await insertComputer('dc-c');
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test("fills only the survivor's empty details", () async {
    await insertTank('keep', computerId: 'dc-a', name: 'Mine');
    await insertTank(
      'dup',
      computerId: 'dc-b',
      name: 'AL80',
      volume: 11.1,
      workingPressure: 207,
    );

    expect(await merge(), isTrue);

    final kept = (await tank('keep'))!;
    expect(kept.tankName, 'Mine');
    expect(kept.volume, 11.1);
    expect(kept.workingPressure, 207);
  });

  test(
    "carries the duplicate's passport, material and record pressures",
    () async {
      await insertTank('keep', computerId: 'dc-a');
      await insertTank('dup', computerId: 'dc-b');
      await (db.update(db.diveTanks)..where((t) => t.id.equals('dup'))).write(
        const DiveTanksCompanion(
          passportId: Value('passport-1'),
          twinPassportId: Value('passport-2'),
          tankMaterial: Value('aluminum'),
          startPressure: Value(207),
          endPressure: Value(50),
        ),
      );

      await merge();

      final kept = (await tank('keep'))!;
      expect(kept.passportId, 'passport-1');
      expect(kept.twinPassportId, 'passport-2');
      expect(kept.tankMaterial, 'aluminum');
      expect(kept.startPressure, 207);
      expect(kept.endPressure, 50);
    },
  );

  test('applies the chosen mix', () async {
    await insertTank('keep', computerId: 'dc-a', o2: 32);
    await insertTank('dup', computerId: 'dc-b', o2: 21);

    await merge(mix: (o2: 21, he: 0));

    expect((await tank('keep'))!.o2Percent, 21);
  });

  test("unions shared computers and adds the duplicate's computer", () async {
    await insertTank('keep', computerId: 'dc-a', sharedWith: ['dc-c']);
    await insertTank('dup', computerId: 'dc-b', sharedWith: ['dc-a']);

    await merge();

    final shared = decodeSharedComputerIds(
      (await tank('keep'))!.sharedComputerIds,
    );
    expect(shared?.toSet(), {'dc-b', 'dc-c'});
  });

  test('moves the series when the survivor has none', () async {
    await insertTank('keep', computerId: 'dc-a');
    await insertTank('dup', computerId: 'dc-b');
    await (db.update(db.diveTanks)..where((t) => t.id.equals('dup'))).write(
      const DiveTanksCompanion(
        startPressure: Value(200),
        endPressure: Value(60),
      ),
    );
    final moved = await insertPressure('dup', 200);

    await merge();

    final rows = await db.select(db.tankPressureSeries).get();
    expect(rows.single.id, moved);
    expect(rows.single.tankId, 'keep');
    final kept = (await tank('keep'))!;
    expect(kept.startPressure, 200);
    expect(kept.endPressure, 60);
  });

  test(
    "keeps the survivor's own parsed-tank index when a series moves",
    () async {
      await insertTank('keep', computerId: 'dc-a');
      await insertTank('dup', computerId: 'dc-b');
      await (db.update(db.diveTanks)..where((t) => t.id.equals('keep'))).write(
        const DiveTanksCompanion(sourceTankIndex: Value(0)),
      );
      await (db.update(db.diveTanks)..where((t) => t.id.equals('dup'))).write(
        const DiveTanksCompanion(sourceTankIndex: Value(2)),
      );
      await insertPressure('dup', 200);

      await merge();

      expect((await tank('keep'))!.sourceTankIndex, 0);
    },
  );

  test(
    "deletes the duplicate's series when the survivor has its own",
    () async {
      await insertTank('keep', computerId: 'dc-a');
      await insertTank('dup', computerId: 'dc-b');
      final own = await insertPressure('keep', 210);
      final other = await insertPressure('dup', 209);

      await merge();

      final rows = await db.select(db.tankPressureSeries).get();
      expect(rows.map((r) => r.id), [own]);
      final tombstones = {
        for (final t in await db.select(db.deletionLog).get()) t.recordId,
      };
      expect(tombstones, contains(other));
    },
  );

  test('re-points gas switches and profile events', () async {
    await insertTank('keep', computerId: 'dc-a');
    await insertTank('dup', computerId: 'dc-b');
    await db
        .into(db.gasSwitches)
        .insert(
          const GasSwitchesCompanion(
            id: Value('switch'),
            diveId: Value('dive'),
            tankId: Value('dup'),
            timestamp: Value(600),
            createdAt: Value(0),
          ),
        );
    await db
        .into(db.diveProfileEvents)
        .insert(
          const DiveProfileEventsCompanion(
            id: Value('event'),
            diveId: Value('dive'),
            tankId: Value('dup'),
            timestamp: Value(600),
            eventType: Value('gasChange'),
            createdAt: Value(0),
          ),
        );

    await merge();

    final sw = await db.select(db.gasSwitches).getSingle();
    expect(sw.tankId, 'keep');
    final event = await db.select(db.diveProfileEvents).getSingle();
    expect(event.tankId, 'keep');
  });

  test('logs the duplicate tank deletion', () async {
    await insertTank('keep', computerId: 'dc-a');
    await insertTank('dup', computerId: 'dc-b');

    await merge();

    expect(await tank('dup'), isNull);
    final tombstones = await db.select(db.deletionLog).get();
    expect(
      tombstones.where((t) => t.recordId == 'dup').single.entityType,
      'diveTanks',
    );
  });

  test('returns false when the duplicates are already gone', () async {
    await insertTank('keep', computerId: 'dc-a');

    expect(await merge(), isFalse);
  });
}
