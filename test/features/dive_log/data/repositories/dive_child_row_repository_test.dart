import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_child_row_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';

import '../../../../helpers/test_database.dart';

/// One row at a time, so an edit to one tank or weight leaves the others, and
/// a tank's pressure series and gas switches, as they were.
void main() {
  late AppDatabase db;
  late DiveChildRowRepository repo;
  const seeded = 1000;

  setUp(() async {
    await setUpTestDatabase();
    db = DatabaseService.instance.database;
    repo = DiveChildRowRepository();
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'd1',
            diveDateTime: 1710408600000,
            createdAt: seeded,
            updatedAt: seeded,
          ),
        );
  });
  tearDown(tearDownTestDatabase);

  Future<void> tank(String id, int order, {double start = 200}) => db
      .into(db.diveTanks)
      .insert(
        DiveTanksCompanion(
          id: Value(id),
          diveId: const Value('d1'),
          tankOrder: Value(order),
          startPressure: Value(start),
          endPressure: const Value(50),
          tankRole: const Value('backGas'),
          roleSource: const Value('transmitterName'),
        ),
      );

  Future<void> weight(String id) => db
      .into(db.diveWeights)
      .insert(
        DiveWeightsCompanion.insert(
          id: id,
          diveId: 'd1',
          weightType: 'belt',
          amountKg: 4,
          createdAt: seeded,
        ),
      );

  Future<DiveTank?> tankRow(String id) => (db.select(
    db.diveTanks,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<DiveWeight?> weightRow(String id) => (db.select(
    db.diveWeights,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> diveVersion() async => (await (db.select(
    db.dives,
  )..where((d) => d.id.equals('d1'))).getSingle()).updatedAt;

  Future<List<String>> tombstones(String entityType) async => [
    for (final t in await db.select(db.deletionLog).get())
      if (t.entityType == entityType) t.recordId,
  ];

  Future<Set<String>> pending(String entityType) async => {
    for (final r in await db.select(db.syncRecords).get())
      if (r.entityType == entityType && r.syncStatus == 'pending') r.recordId,
  };

  group('tanks', () {
    test('an add goes after the tanks the dive has', () async {
      await tank('t1', 0);
      await tank('t2', 1);

      final id = await repo.addTank(
        'd1',
        const DiveTanksCompanion(o2Percent: Value(32), volume: Value(12)),
      );

      final row = (await tankRow(id))!;
      expect(row.tankOrder, 2);
      expect(row.o2Percent, 32);
      expect(row.volume, 12);
      expect(row.diveId, 'd1');
      expect((await tankRow('t1'))!.startPressure, 200);
      expect(await pending('diveTanks'), {id});
      expect(await diveVersion(), greaterThan(seeded));
    });

    test('an add goes after the highest order, past a gap', () async {
      await tank('t1', 0);
      await tank('t3', 2);

      final id = await repo.addTank('d1', const DiveTanksCompanion());

      expect((await tankRow(id))!.tankOrder, 3);
    });

    test('an add keeps an order it is given', () async {
      final id = await repo.addTank(
        'd1',
        const DiveTanksCompanion(tankOrder: Value(5)),
      );

      expect((await tankRow(id))!.tankOrder, 5);
    });

    test('an update writes only the columns it names', () async {
      await tank('t1', 0);
      await tank('t2', 1, start: 210);

      final found = await repo.updateTank(
        't1',
        const DiveTanksCompanion(volume: Value(15)),
      );

      expect(found, isTrue);
      final row = (await tankRow('t1'))!;
      expect(row.volume, 15);
      expect(row.startPressure, 200);
      expect(row.endPressure, 50);
      expect(row.roleSource, 'transmitterName');
      expect((await tankRow('t2'))!.startPressure, 210);
      expect(await pending('diveTanks'), {'t1'});
      expect(await diveVersion(), greaterThan(seeded));
    });

    test(
      'a role the diver sets is no longer the transmitter name\'s',
      () async {
        await tank('t1', 0);

        await repo.updateTank(
          't1',
          const DiveTanksCompanion(tankRole: Value('stage')),
        );

        final row = (await tankRow('t1'))!;
        expect(row.tankRole, 'stage');
        expect(row.roleSource, isNull);
      },
    );

    test('an update of a tank that has gone finds nothing', () async {
      expect(
        await repo.updateTank(
          'gone',
          const DiveTanksCompanion(volume: Value(1)),
        ),
        isFalse,
      );
      expect(await diveVersion(), seeded);
    });

    test(
      'a delete takes the tank\'s series and switches, tombstoned',
      () async {
        await tank('t1', 0);
        await tank('t2', 1);
        final series = TankPressureSeriesRepository();
        final s1 = await series.insertSeries(
          diveId: 'd1',
          tankId: 't1',
          samples: const [TankPressureSample(timestamp: 0, pressure: 200)],
        );
        final s2 = await series.insertSeries(
          diveId: 'd1',
          tankId: 't2',
          samples: const [TankPressureSample(timestamp: 0, pressure: 210)],
        );
        for (final (id, tankId) in [('g1', 't1'), ('g2', 't2')]) {
          await db
              .into(db.gasSwitches)
              .insert(
                GasSwitchesCompanion(
                  id: Value(id),
                  diveId: const Value('d1'),
                  timestamp: const Value(60),
                  tankId: Value(tankId),
                  createdAt: const Value(0),
                ),
              );
        }

        expect(await repo.deleteTank('t1'), isTrue);

        expect(await tankRow('t1'), isNull);
        expect(await tankRow('t2'), isNotNull);
        final seriesLeft = await db.select(db.tankPressureSeries).get();
        expect([for (final s in seriesLeft) s.id], [s2]);
        final switchesLeft = await db.select(db.gasSwitches).get();
        expect([for (final s in switchesLeft) s.id], ['g2']);
        expect(await tombstones('diveTanks'), ['t1']);
        expect(await tombstones('gasSwitches'), ['g1']);
        expect(await tombstones('tankPressureSeries'), [s1]);
        expect(await diveVersion(), greaterThan(seeded));
      },
    );

    test('a delete clears the events that name the tank', () async {
      await tank('t1', 0);
      await db
          .into(db.diveProfileEvents)
          .insert(
            DiveProfileEventsCompanion.insert(
              id: 'e1',
              diveId: 'd1',
              timestamp: 60,
              eventType: 'gasChange',
              createdAt: 0,
              tankId: const Value('t1'),
            ),
          );

      await repo.deleteTank('t1');

      final event = await (db.select(
        db.diveProfileEvents,
      )..where((e) => e.id.equals('e1'))).getSingle();
      expect(event.tankId, isNull);
      expect(await pending('diveProfileEvents'), {'e1'});
    });

    test('a delete of a tank that has gone finds nothing', () async {
      expect(await repo.deleteTank('gone'), isFalse);
      expect(await tombstones('diveTanks'), isEmpty);
    });
  });

  group('weights', () {
    test('an add stores a trimmed label and marks the row', () async {
      await weight('w1');

      final id = await repo.addWeight(
        'd1',
        const DiveWeightsCompanion(
          weightType: Value('integrated'),
          amountKg: Value(2.5),
          label: Value('  Pockets  '),
        ),
      );

      final row = (await weightRow(id))!;
      expect(row.weightType, 'integrated');
      expect(row.amountKg, 2.5);
      expect(row.label, 'Pockets');
      expect(row.diveId, 'd1');
      expect((await weightRow('w1'))!.amountKg, 4);
      expect(await pending('diveWeights'), {id});
      expect(await diveVersion(), greaterThan(seeded));
    });

    test('an update writes only the columns it names', () async {
      await weight('w1');
      await weight('w2');

      expect(
        await repo.updateWeight(
          'w1',
          const DiveWeightsCompanion(notes: Value('new notes')),
        ),
        isTrue,
      );

      final row = (await weightRow('w1'))!;
      expect(row.notes, 'new notes');
      expect(row.amountKg, 4);
      expect(row.weightType, 'belt');
      expect(await pending('diveWeights'), {'w1'});
      expect(await diveVersion(), greaterThan(seeded));
    });

    test('a delete removes the row and tombstones it', () async {
      await weight('w1');
      await weight('w2');

      expect(await repo.deleteWeight('w1'), isTrue);

      expect(await weightRow('w1'), isNull);
      expect(await weightRow('w2'), isNotNull);
      expect(await tombstones('diveWeights'), ['w1']);
      expect(await diveVersion(), greaterThan(seeded));
    });

    test('a weight that has gone finds nothing', () async {
      expect(
        await repo.updateWeight(
          'gone',
          const DiveWeightsCompanion(notes: Value('x')),
        ),
        isFalse,
      );
      expect(await repo.deleteWeight('gone'), isFalse);
      expect(await diveVersion(), seeded);
    });
  });

  group('custom fields', () {
    Future<void> field(String id, int order) => db
        .into(db.diveCustomFields)
        .insert(
          DiveCustomFieldsCompanion.insert(
            id: id,
            diveId: 'd1',
            fieldKey: 'key $id',
            fieldValue: Value('value $id'),
            sortOrder: Value(order),
            createdAt: seeded,
          ),
        );

    Future<DiveCustomField?> fieldRow(String id) => (db.select(
      db.diveCustomFields,
    )..where((f) => f.id.equals(id))).getSingleOrNull();

    test('an add goes after the highest order and marks the row', () async {
      await field('f1', 0);
      await field('f3', 2);

      final id = await repo.addCustomField(
        'd1',
        const DiveCustomFieldsCompanion(
          fieldKey: Value('Camera'),
          fieldValue: Value('GoPro'),
        ),
      );

      final row = (await fieldRow(id))!;
      expect(row.fieldKey, 'Camera');
      expect(row.fieldValue, 'GoPro');
      expect(row.sortOrder, 3);
      expect(row.diveId, 'd1');
      expect(await pending('diveCustomFields'), {id});
      expect(await diveVersion(), greaterThan(seeded));
    });

    test('an update writes only the columns it names', () async {
      await field('f1', 0);
      await field('f2', 1);

      expect(
        await repo.updateCustomField(
          'f1',
          const DiveCustomFieldsCompanion(fieldValue: Value('changed')),
        ),
        isTrue,
      );

      final row = (await fieldRow('f1'))!;
      expect(row.fieldValue, 'changed');
      expect(row.fieldKey, 'key f1');
      expect((await fieldRow('f2'))!.fieldValue, 'value f2');
      expect(await pending('diveCustomFields'), {'f1'});
      expect(await diveVersion(), greaterThan(seeded));
    });

    test('a delete removes the row and tombstones it', () async {
      await field('f1', 0);

      expect(await repo.deleteCustomField('f1'), isTrue);

      expect(await fieldRow('f1'), isNull);
      expect(await tombstones('diveCustomFields'), ['f1']);
      expect(await diveVersion(), greaterThan(seeded));
    });

    test('a field that has gone finds nothing', () async {
      expect(
        await repo.updateCustomField(
          'gone',
          const DiveCustomFieldsCompanion(fieldValue: Value('x')),
        ),
        isFalse,
      );
      expect(await repo.deleteCustomField('gone'), isFalse);
      expect(await diveVersion(), seeded);
    });
  });
}
