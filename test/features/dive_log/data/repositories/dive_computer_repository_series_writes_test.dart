import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DiveComputerRepository computers;
  late ProfileSeriesRepository series;
  late TankPressureSeriesRepository tankSeries;

  Future<void> insertDive(String id) async {
    const now = 1750000000000;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: id,
            diveDateTime: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<void> insertComputer(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion(
            id: Value(id),
            name: Value('Computer $id'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  setUp(() async {
    db = await setUpTestDatabase();
    computers = DiveComputerRepository();
    series = ProfileSeriesRepository();
    tankSeries = TankPressureSeriesRepository();
    await insertComputer('comp-1');
    await insertComputer('comp-2');
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  // isPrimary is passed false on purpose: a dive with no series makes the
  // import primary regardless (the legacy `hasProfiles == 0` rule).
  Future<String> importDive({String computerId = 'comp-1'}) =>
      computers.importProfile(
        computerId: computerId,
        profileStartTime: DateTime(2026, 1, 1, 10),
        points: const [
          ProfilePointData(
            timestamp: 30,
            depth: 10.0,
            pressure: 190.0,
            tankIndex: 0,
          ),
          ProfilePointData(
            timestamp: 0,
            depth: 0.0,
            pressure: 200.0,
            tankIndex: 0,
          ),
        ],
        durationSeconds: 60,
        maxDepth: 10.0,
        isPrimary: false,
        tanks: const [TankData(index: 0, o2Percent: 21.0)],
      );

  test(
    'a first import writes one primary series owned by the computer and its source, and one tank series',
    () async {
      final diveId = await importDive();
      final rows = await series.getSeriesForDive(diveId);
      expect(rows, hasLength(1));
      expect(rows.single.isPrimary, isTrue);
      expect(rows.single.computerId, 'comp-1');
      expect(rows.single.sourceId, isNotNull);
      expect(rows.single.samples.map((s) => s.timestamp), [0, 30]);
      final tanks = await tankSeries.getSeriesForDive(diveId);
      expect(tanks, hasLength(1));
      expect(tanks.single.computerId, 'comp-1');
      expect(tanks.single.samples.map((s) => s.pressure), [200.0, 190.0]);
    },
  );

  test(
    'a second import of the same dive and computer does not insert a second series',
    () async {
      final first = await importDive();
      final second = await importDive();
      expect(second, first);
      expect(await series.getSeriesForDive(first), hasLength(1));
      expect(await tankSeries.getSeriesForDive(first), hasLength(1));
    },
  );

  test(
    'setPrimaryProfile flips the flags by computer and writes no tombstone',
    () async {
      final diveId = await importDive();
      final second = await series.insertSeries(
        diveId: diveId,
        computerId: 'comp-2',
        isPrimary: false,
        samples: const [ProfileSample(timestamp: 0, depth: 2.0)],
        now: 1000,
      );
      await computers.setPrimaryProfile(diveId, 'comp-2');
      final rows = await series.getSeriesForDive(diveId);
      expect(rows.firstWhere((s) => s.id == second).isPrimary, isTrue);
      expect(rows.firstWhere((s) => s.id != second).isPrimary, isFalse);
      expect(await db.select(db.deletionLog).get(), isEmpty);
    },
  );

  test(
    'clearSourceAndProfiles deletes the computer profile series and every tank series of the dive',
    () async {
      final diveId = await importDive();
      final imported = (await series.getSeriesForDive(diveId)).single.id;
      final tank = (await tankSeries.getSeriesForDive(diveId)).single.id;
      final edit = await series.insertSeries(
        diveId: diveId,
        samples: const [ProfileSample(timestamp: 0, depth: 9.0)],
        now: 1000,
      );
      await computers.clearSourceAndProfiles(
        diveId: diveId,
        computerId: 'comp-1',
      );
      expect((await series.getSeriesForDive(diveId)).map((s) => s.id), [edit]);
      expect(await tankSeries.getSeriesForDive(diveId), isEmpty);
      final tombstones = await db.select(db.deletionLog).get();
      expect(tombstones.map((t) => t.recordId).toSet(), {imported, tank});
    },
  );
  test(
    'clearSourceAndProfiles restamps the edited series whose source it deletes',
    () async {
      // deleteByComputer never matches the null-computer edit, so the edit
      // survives the clear while the cascade on the deleted
      // dive_data_sources row nulls its source_id: ON DELETE SET NULL moves
      // no updated_at, restamps no hlc and marks nothing pending, so this
      // device reads the edit as unattributed while every peer still reads
      // it as owned by the deleted source, permanently.
      final diveId = await importDive();
      final sourceId = (await series.getSeriesForDive(diveId)).single.sourceId;
      final edit = await series.insertSeries(
        diveId: diveId,
        sourceId: sourceId,
        samples: const [ProfileSample(timestamp: 0, depth: 9.0)],
        now: 1000,
      );
      final before = (await series.getRowsForDives([
        diveId,
      ])).firstWhere((r) => r.id == edit);
      await computers.clearSourceAndProfiles(
        diveId: diveId,
        computerId: 'comp-1',
      );
      final after = (await series.getRowsForDives([
        diveId,
      ])).firstWhere((r) => r.id == edit);
      expect(after.sourceId, isNull);
      expect(after.updatedAt, greaterThan(before.updatedAt));
      expect(after.hlc, isNot(before.hlc));
    },
  );

  test(
    'the computer list survives a series whose blob will not decode',
    () async {
      // These questions are about identity columns, which live unencoded on
      // the row. Answering them through the decoded read dropped an
      // unreadable series entirely, so its computer vanished from the chip
      // list and from the primary lookup that picks restoreOriginalProfile's
      // branch.
      await insertDive('dive-1');
      await insertComputer('dc-a');
      await insertComputer('dc-b');
      final broken = await series.insertSeries(
        diveId: 'dive-1',
        computerId: 'dc-a',
        isPrimary: true,
        samples: const [ProfileSample(timestamp: 0, depth: 3.0)],
        now: 1000,
      );
      await series.insertSeries(
        diveId: 'dive-1',
        computerId: 'dc-b',
        isPrimary: false,
        samples: const [ProfileSample(timestamp: 0, depth: 4.0)],
        now: 1000,
      );
      final row = (await series.getRowsForDives([
        'dive-1',
      ])).firstWhere((r) => r.id == broken);
      await db.customStatement(
        'UPDATE dive_profile_series SET samples = ? WHERE id = ?',
        [Uint8List.fromList(row.samples)..[3] ^= 0xFF, broken],
      );

      expect(
        await computers.getComputerIdsForDive('dive-1'),
        unorderedEquals(['dc-a', 'dc-b']),
      );
      expect(await computers.getPrimaryComputerId('dive-1'), 'dc-a');
    },
  );

  test(
    'setPrimaryProfile on a computer that owns no series changes nothing',
    () async {
      // demoteAll then promoteByComputer as two separate commits leaves the
      // dive with NO primary series whenever the promote matches nothing: a
      // null-computer series after a clearComputer, a consolidation that
      // moved samples, a metadata-only source. The dive keeps rendering
      // (getDiveById and getMergedProfile ignore the flag) while
      // getDiveProfile, the rate aggregates and the quality prefilters all
      // silently skip it. DiveRepository.setPrimaryDataSource guards the same
      // pair with ownsAny.
      await insertDive('dive-1');
      await insertComputer('dc-a');
      await series.insertSeries(
        diveId: 'dive-1',
        isPrimary: true,
        samples: const [ProfileSample(timestamp: 0, depth: 3.0)],
        now: 1000,
      );

      await computers.setPrimaryProfile('dive-1', 'dc-a');

      final rows = await series.getRowsForDives(['dive-1']);
      expect(
        rows.where((r) => r.isPrimary),
        hasLength(1),
        reason: 'a dive must never be left with zero primary series',
      );
    },
  );

  test(
    'setPrimaryProfile promotes the computer that does own series',
    () async {
      await insertDive('dive-1');
      await insertComputer('dc-a');
      await insertComputer('dc-b');
      await series.insertSeries(
        diveId: 'dive-1',
        computerId: 'dc-a',
        isPrimary: true,
        samples: const [ProfileSample(timestamp: 0, depth: 3.0)],
        now: 1000,
      );
      await series.insertSeries(
        diveId: 'dive-1',
        computerId: 'dc-b',
        isPrimary: false,
        samples: const [ProfileSample(timestamp: 0, depth: 4.0)],
        now: 1000,
      );

      await computers.setPrimaryProfile('dive-1', 'dc-b');

      final rows = await series.getRowsForDives(['dive-1']);
      expect(
        {for (final r in rows) r.computerId: r.isPrimary},
        {'dc-a': false, 'dc-b': true},
      );
    },
  );
}
