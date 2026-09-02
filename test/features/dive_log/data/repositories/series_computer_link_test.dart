import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ProfileSeriesRepository profileSeries;
  late TankPressureSeriesRepository tankSeries;

  const one = [ProfileSample(timestamp: 0, depth: 1.0)];
  const onePressure = [TankPressureSample(timestamp: 0, pressure: 200.0)];

  var dataSourceCounter = 0;

  Future<void> insertDiver(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: id,
            name: 'Diver $id',
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<void> insertDive(String id, {String? diverId}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: id,
            diveDateTime: now,
            diverId: Value(diverId),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<void> insertComputer(String id, {String? diverId}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion.insert(
            id: id,
            name: id,
            diverId: Value(diverId),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<void> insertTank(String id, String diveId) async {
    await db
        .into(db.diveTanks)
        .insert(DiveTanksCompanion.insert(id: id, diveId: diveId));
  }

  /// Adds one `dive_data_sources` row whose `source_format` is
  /// 'dive_computer', the predicate [relinkComputer] counts against.
  Future<void> insertComputerDataSource(String diveId) async {
    final now = DateTime.now();
    dataSourceCounter++;
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion.insert(
            id: 'ds-$dataSourceCounter',
            diveId: diveId,
            sourceFormat: const Value('dive_computer'),
            importedAt: now,
            createdAt: now,
          ),
        );
  }

  setUp(() async {
    db = await setUpTestDatabase();
    profileSeries = ProfileSeriesRepository();
    tankSeries = TankPressureSeriesRepository();
    dataSourceCounter = 0;

    await insertDiver('diver-a');
    await insertDiver('diver-b');
    await insertDive('d-mine', diverId: 'diver-a');
    await insertDive('d-theirs', diverId: 'diver-b');
    await insertComputer('comp-a', diverId: 'diver-a');
    await insertComputer('comp-x');
    await insertTank('tank-mine', 'd-mine');
    await insertTank('tank-theirs', 'd-theirs');
  });

  tearDown(tearDownTestDatabase);

  group('ProfileSeriesRepository computer link', () {
    test('clearComputer nulls the computer on every series of that computer '
        'and restamps hlc', () async {
      final id = await profileSeries.insertSeries(
        diveId: 'd-mine',
        computerId: 'comp-a',
        samples: one,
        now: 1000,
      );
      final keep = await profileSeries.insertSeries(
        diveId: 'd-mine',
        computerId: 'comp-x',
        samples: one,
        now: 1000,
      );
      final before = (await profileSeries.getRowsForDives([
        'd-mine',
      ])).firstWhere((r) => r.id == id).hlc;
      expect(await profileSeries.clearComputer('comp-a', now: 2000), 1);
      final rows = await profileSeries.getRowsForDives(['d-mine']);
      expect(rows.firstWhere((r) => r.id == id).computerId, isNull);
      expect(rows.firstWhere((r) => r.id == id).hlc, isNot(before));
      expect(rows.firstWhere((r) => r.id == keep).computerId, 'comp-x');
    });

    test('clearComputersOfDiverForForeignDives touches only dives the diver '
        'does not own', () async {
      final mine = await profileSeries.insertSeries(
        diveId: 'd-mine',
        computerId: 'comp-a',
        samples: one,
        now: 1000,
      );
      final theirs = await profileSeries.insertSeries(
        diveId: 'd-theirs',
        computerId: 'comp-a',
        samples: one,
        now: 1000,
      );
      expect(
        await profileSeries.clearComputersOfDiverForForeignDives(
          'diver-a',
          now: 2000,
        ),
        1,
      );
      final rows = await profileSeries.getRowsForDives(['d-mine', 'd-theirs']);
      expect(rows.firstWhere((r) => r.id == mine).computerId, 'comp-a');
      expect(rows.firstWhere((r) => r.id == theirs).computerId, isNull);
    });

    test('relinkComputer stamps null-computer series of dives with exactly '
        'one computer source', () async {
      // d-mine has ONE dive_data_sources row with source_format
      // 'dive_computer'; d-theirs has TWO. Both carry a null-computer
      // series.
      await insertComputerDataSource('d-mine');
      await insertComputerDataSource('d-theirs');
      await insertComputerDataSource('d-theirs');
      final a = await profileSeries.insertSeries(
        diveId: 'd-mine',
        samples: one,
        now: 1000,
      );
      final b = await profileSeries.insertSeries(
        diveId: 'd-theirs',
        samples: one,
        now: 1000,
      );
      expect(
        await profileSeries.relinkComputer('comp-a', [
          'd-mine',
          'd-theirs',
        ], now: 2000),
        1,
      );
      final rows = await profileSeries.getRowsForDives(['d-mine', 'd-theirs']);
      expect(rows.firstWhere((r) => r.id == a).computerId, 'comp-a');
      expect(rows.firstWhere((r) => r.id == b).computerId, isNull);
    });

    test('relinkComputer leaves a user-edited series unattributed and takes '
        'back the demoted original', () async {
      // The state a re-added computer finds on a dive the user edited before
      // the old computer was deleted: the computer's own samples demoted and
      // stripped of their computer by clearComputer, and the manual edit
      // primary with a null computer of its own. Stamping the edit hands it
      // to the next reparse, whose first act is deleteByComputer, and a
      // series is deleted whole.
      await insertComputerDataSource('d-mine');
      final original = await profileSeries.insertSeries(
        diveId: 'd-mine',
        isPrimary: false,
        samples: one,
        now: 1000,
      );
      final edit = await profileSeries.insertSeries(
        diveId: 'd-mine',
        isPrimary: true,
        samples: one,
        now: 1000,
      );
      expect(
        await profileSeries.relinkComputer('comp-a', ['d-mine'], now: 2000),
        1,
      );
      final rows = await profileSeries.getRowsForDives(['d-mine']);
      expect(rows.firstWhere((r) => r.id == original).computerId, 'comp-a');
      expect(rows.firstWhere((r) => r.id == edit).computerId, isNull);
    });

    test(
      'relinkComputer still stamps the live series of an unedited dive',
      () async {
        // The same shape without an edit: one primary null-computer series and
        // nothing demoted beside it, which is what a plain computer delete
        // leaves behind. That one is the computer's own and has to come back.
        await insertComputerDataSource('d-mine');
        final live = await profileSeries.insertSeries(
          diveId: 'd-mine',
          isPrimary: true,
          samples: one,
          now: 1000,
        );
        expect(
          await profileSeries.relinkComputer('comp-a', ['d-mine'], now: 2000),
          1,
        );
        final rows = await profileSeries.getRowsForDives(['d-mine']);
        expect(rows.firstWhere((r) => r.id == live).computerId, 'comp-a');
      },
    );
  });

  group('TankPressureSeriesRepository computer link', () {
    test('clearComputer nulls the computer on every series of that computer '
        'and restamps hlc', () async {
      final id = await tankSeries.insertSeries(
        diveId: 'd-mine',
        tankId: 'tank-mine',
        computerId: 'comp-a',
        samples: onePressure,
        now: 1000,
      );
      final keep = await tankSeries.insertSeries(
        diveId: 'd-mine',
        tankId: 'tank-mine',
        computerId: 'comp-x',
        samples: onePressure,
        now: 1000,
      );
      final before = (await tankSeries.getRowsForDives([
        'd-mine',
      ])).firstWhere((r) => r.id == id).hlc;
      expect(await tankSeries.clearComputer('comp-a', now: 2000), 1);
      final rows = await tankSeries.getRowsForDives(['d-mine']);
      expect(rows.firstWhere((r) => r.id == id).computerId, isNull);
      expect(rows.firstWhere((r) => r.id == id).hlc, isNot(before));
      expect(rows.firstWhere((r) => r.id == keep).computerId, 'comp-x');
    });

    test('clearComputersOfDiverForForeignDives touches only dives the diver '
        'does not own', () async {
      final mine = await tankSeries.insertSeries(
        diveId: 'd-mine',
        tankId: 'tank-mine',
        computerId: 'comp-a',
        samples: onePressure,
        now: 1000,
      );
      final theirs = await tankSeries.insertSeries(
        diveId: 'd-theirs',
        tankId: 'tank-theirs',
        computerId: 'comp-a',
        samples: onePressure,
        now: 1000,
      );
      expect(
        await tankSeries.clearComputersOfDiverForForeignDives(
          'diver-a',
          now: 2000,
        ),
        1,
      );
      final rows = await tankSeries.getRowsForDives(['d-mine', 'd-theirs']);
      expect(rows.firstWhere((r) => r.id == mine).computerId, 'comp-a');
      expect(rows.firstWhere((r) => r.id == theirs).computerId, isNull);
    });
  });

  group('DiveComputerRepository computer delete / series reads', () {
    test(
      'deleteComputer clears the series before the FK cascade would',
      () async {
        final profileId = await profileSeries.insertSeries(
          diveId: 'd-mine',
          computerId: 'comp-a',
          samples: one,
          now: 1000,
        );
        final tankId = await tankSeries.insertSeries(
          diveId: 'd-mine',
          tankId: 'tank-mine',
          computerId: 'comp-a',
          samples: onePressure,
          now: 1000,
        );
        final beforeProfileHlc = (await profileSeries.getRowsForDives([
          'd-mine',
        ])).firstWhere((r) => r.id == profileId).hlc;
        final beforeTankHlc = (await tankSeries.getRowsForDives([
          'd-mine',
        ])).firstWhere((r) => r.id == tankId).hlc;

        await DiveComputerRepository().deleteComputer('comp-a');

        final profileRows = await profileSeries.getRowsForDives(['d-mine']);
        final tankRows = await tankSeries.getRowsForDives(['d-mine']);
        final profileRow = profileRows.firstWhere((r) => r.id == profileId);
        final tankRow = tankRows.firstWhere((r) => r.id == tankId);
        expect(profileRow.computerId, isNull);
        expect(profileRow.hlc, isNot(beforeProfileHlc));
        expect(tankRow.computerId, isNull);
        expect(tankRow.hlc, isNot(beforeTankHlc));
      },
    );

    test('deleteComputer survives a leftover legacy dive_profiles', () async {
      // v183 drops dive_profiles only once its rows have moved, so a device
      // whose pack threw keeps the table, and its computer_id FK carries no
      // ON DELETE action. Leaving it set fails the dive_computers delete
      // with SqliteException(787), which is issue #823 all over again.
      await db.customStatement(
        'CREATE TABLE dive_profiles ('
        'id TEXT NOT NULL PRIMARY KEY, '
        'dive_id TEXT NOT NULL REFERENCES dives (id) ON DELETE CASCADE, '
        'computer_id TEXT REFERENCES dive_computers (id), '
        'timestamp INTEGER NOT NULL, '
        'depth REAL NOT NULL)',
      );
      await db.customStatement(
        'INSERT INTO dive_profiles (id, dive_id, computer_id, timestamp, '
        "depth) VALUES ('legacy-1', 'd-mine', 'comp-a', 0, 1.0)",
      );

      await expectLater(
        DiveComputerRepository().deleteComputer('comp-a'),
        completes,
      );

      final rows = await db
          .customSelect('SELECT computer_id FROM dive_profiles')
          .get();
      expect(rows.single.data['computer_id'], isNull);
      expect(
        await (db.select(
          db.diveComputers,
        )..where((t) => t.id.equals('comp-a'))).getSingleOrNull(),
        isNull,
      );
    });

    test('getDiveIdsForComputer lists dives by their series', () async {
      await profileSeries.insertSeries(
        diveId: 'd-mine',
        computerId: 'comp-a',
        samples: one,
        now: 1000,
      );
      expect(await DiveComputerRepository().getDiveIdsForComputer('comp-a'), [
        'd-mine',
      ]);
      expect(
        await DiveComputerRepository().getDiveIdsForComputer('comp-x'),
        isEmpty,
      );
    });
  });
}
