import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DiveRepository dives;
  late ProfileSeriesRepository series;

  Future<void> computer(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion.insert(
            id: id,
            name: 'Comp $id',
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<void> source(
    String id,
    String diveId,
    String? computerId, {
    bool primary = false,
  }) async {
    final now = DateTime.now();
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion.insert(
            id: id,
            diveId: diveId,
            computerId: Value(computerId),
            isPrimary: Value(primary),
            importedAt: now,
            createdAt: now,
          ),
        );
  }

  /// The `local_updated_at` of the pending sync record of [seriesId], or null
  /// when the series was never marked pending.
  Future<int?> pendingSince(String seriesId) async {
    final row = await db
        .customSelect(
          "SELECT local_updated_at AS t FROM sync_records "
          "WHERE entity_type = 'diveProfileSeries' AND record_id = ? "
          "AND sync_status = 'pending'",
          variables: [Variable<String>(seriesId)],
        )
        .getSingleOrNull();
    return row?.read<int>('t');
  }

  setUp(() async {
    db = await setUpTestDatabase();
    dives = DiveRepository();
    series = ProfileSeriesRepository();
  });

  tearDown(tearDownTestDatabase);

  domain.Dive dive(String id, List<domain.DiveProfilePoint> profile) =>
      domain.Dive(id: id, dateTime: DateTime(2026, 1, 1), profile: profile);

  test(
    'createDive writes one primary null-identity series and no legacy rows',
    () async {
      await dives.createDive(
        dive('dive-1', const [
          domain.DiveProfilePoint(timestamp: 10, depth: 5.0),
          domain.DiveProfilePoint(timestamp: 0, depth: 0.0),
        ]),
      );
      final rows = await series.getSeriesForDive('dive-1');
      expect(rows, hasLength(1));
      expect(rows.single.isPrimary, isTrue);
      expect(rows.single.computerId, isNull);
      expect(rows.single.sourceId, isNull);
      expect(rows.single.samples.map((s) => s.timestamp), [0, 10]);
    },
  );

  test('createDive with no profile writes no series row', () async {
    await dives.createDive(dive('dive-1', const []));
    expect(await series.getSeriesForDive('dive-1'), isEmpty);
  });

  test(
    'createDive rolls everything back when the series write fails',
    () async {
      // A NaN depth encodes fine and then fails the series insert: SQLite has
      // no NaN, so the bound summary depths arrive as NULL and the NOT NULL
      // constraint rejects the row. Any failure of that write must leave the
      // dive absent rather than half written, because createDive rethrows and
      // every caller reports total failure.
      await expectLater(
        dives.createDive(
          dive('dive-1', const [
            domain.DiveProfilePoint(timestamp: 0, depth: double.nan),
          ]),
        ),
        throwsA(anything),
      );
      expect(await db.select(db.dives).get(), isEmpty);
      expect(await db.select(db.diveDiveTypes).get(), isEmpty);
      expect(await series.getSeriesForDive('dive-1'), isEmpty);
    },
  );

  test(
    'saveEditedProfile demotes every series and inserts the edit under the primary source',
    () async {
      await dives.createDive(
        dive('dive-1', const [
          domain.DiveProfilePoint(timestamp: 0, depth: 1.0),
        ]),
      );
      await computer('comp-1');
      await source('src-1', 'dive-1', 'comp-1', primary: true);
      await series.insertSeries(
        diveId: 'dive-1',
        computerId: 'comp-1',
        sourceId: 'src-1',
        samples: const [ProfileSample(timestamp: 0, depth: 2.0)],
        now: 1000,
      );
      await dives.saveEditedProfile('dive-1', const [
        domain.DiveProfilePoint(timestamp: 0, depth: 9.0),
        domain.DiveProfilePoint(timestamp: 5, depth: 8.0),
      ]);
      final rows = await series.getSeriesForDive('dive-1');
      final primary = rows.where((s) => s.isPrimary).toList();
      expect(primary, hasLength(1));
      expect(primary.single.computerId, isNull);
      expect(primary.single.sourceId, 'src-1');
      expect(primary.single.samples.map((s) => s.depth), [9.0, 8.0]);
      expect(rows.where((s) => !s.isPrimary), hasLength(2));
      expect((await dives.getDiveProfile('dive-1')).map((p) => p.depth), [
        9.0,
        8.0,
      ]);
      final row = await (db.select(
        db.dives,
      )..where((t) => t.id.equals('dive-1'))).getSingle();
      expect(row.maxDepth, 9.0);
    },
  );

  test(
    'restoreOriginalProfile deletes the edit and re-promotes the primary computer only',
    () async {
      await computer('comp-1');
      await computer('comp-2');
      await dives.createDive(dive('dive-1', const []));
      await source('src-1', 'dive-1', 'comp-1', primary: true);
      await source('src-2', 'dive-1', 'comp-2');
      final a = await series.insertSeries(
        diveId: 'dive-1',
        computerId: 'comp-1',
        sourceId: 'src-1',
        isPrimary: false,
        samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
        now: 1000,
      );
      final b = await series.insertSeries(
        diveId: 'dive-1',
        computerId: 'comp-2',
        sourceId: 'src-2',
        isPrimary: false,
        samples: const [ProfileSample(timestamp: 0, depth: 2.0)],
        now: 1000,
      );
      final edit = await series.insertSeries(
        diveId: 'dive-1',
        sourceId: 'src-1',
        samples: const [ProfileSample(timestamp: 0, depth: 9.0)],
        now: 1000,
      );
      await dives.restoreOriginalProfile('dive-1');
      final rows = await series.getSeriesForDive('dive-1');
      expect(rows.map((s) => s.id).toSet(), {a, b});
      expect(rows.firstWhere((s) => s.id == a).isPrimary, isTrue);
      expect(rows.firstWhere((s) => s.id == b).isPrimary, isFalse);
      final tombstones = await db.select(db.deletionLog).get();
      expect(tombstones.map((t) => t.recordId), [edit]);
    },
  );

  test(
    'restoreOriginalProfile on a single-computer dive promotes everything left',
    () async {
      await dives.createDive(dive('dive-1', const []));
      await series.insertSeries(
        diveId: 'dive-1',
        isPrimary: false,
        samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
        now: 1000,
      );
      await series.insertSeries(
        diveId: 'dive-1',
        isPrimary: false,
        samples: const [ProfileSample(timestamp: 5, depth: 2.0)],
        now: 1000,
      );
      await dives.restoreOriginalProfile('dive-1');
      expect(
        (await series.getSeriesForDive('dive-1')).every((s) => s.isPrimary),
        isTrue,
      );
    },
  );

  test(
    'restoreOriginalProfile leaves a primary when the primary source owns no series',
    () async {
      // The primary dive_data_sources row names comp-1, which owns nothing:
      // a metadata-only source, or one whose samples a consolidation
      // re-stamped onto another computer. Deleting the edit and then
      // promoting by comp-1 matches zero rows, and the dive is left with no
      // primary series at all. It keeps rendering, because getDiveById and
      // getMergedProfile ignore the flag, while getDiveProfile,
      // getAscentDescentRates, getTimeAtDepthRanges and the data-quality
      // prefilters all silently skip it (issue #1149).
      await computer('comp-1');
      await computer('comp-2');
      await dives.createDive(dive('dive-1', const []));
      await source('src-1', 'dive-1', 'comp-1', primary: true);
      final owned = await series.insertSeries(
        diveId: 'dive-1',
        computerId: 'comp-2',
        isPrimary: false,
        samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
        now: 1000,
      );
      await series.insertSeries(
        diveId: 'dive-1',
        sourceId: 'src-1',
        samples: const [ProfileSample(timestamp: 0, depth: 9.0)],
        now: 1000,
      );
      await dives.restoreOriginalProfile('dive-1');
      final rows = await series.getSeriesForDive('dive-1');
      expect(rows.map((s) => s.id), [owned]);
      expect(rows.single.isPrimary, isTrue);
      expect((await dives.getDiveProfile('dive-1')).map((p) => p.depth), [1.0]);
    },
  );

  test(
    'deleteComputerReading restamps the series whose source it deletes',
    () async {
      // dive_profile_series.source_id is ON DELETE SET NULL, so the cascade
      // changes the row with no updated_at bump, no hlc restamp and nothing
      // pending. This device then reads the series as unattributed while
      // every peer still reads it as owned by the deleted source, and no
      // later write republishes it.
      await computer('comp-1');
      await dives.createDive(dive('dive-1', const []));
      await source('src-1', 'dive-1', 'comp-1', primary: true);
      final id = await series.insertSeries(
        diveId: 'dive-1',
        computerId: 'comp-1',
        sourceId: 'src-1',
        samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
        now: 1000,
      );
      final before = (await series.getRowsForDives(['dive-1'])).single;
      await dives.deleteComputerReading('src-1');
      final after = (await series.getRowsForDives(['dive-1'])).single;
      expect(after.sourceId, isNull);
      expect(after.updatedAt, greaterThan(before.updatedAt));
      expect(after.hlc, isNot(before.hlc));
      expect(await pendingSince(id), greaterThan(1000));
    },
  );

  test(
    'saveComputerReading adopts the unattributed series of a single-source dive',
    () async {
      await computer('comp-1');
      await dives.createDive(
        dive('dive-1', const [
          domain.DiveProfilePoint(timestamp: 0, depth: 1.0),
        ]),
      );
      await dives.saveComputerReading(
        DiveDataSourcesCompanion.insert(
          id: 'src-1',
          diveId: 'dive-1',
          computerId: const Value('comp-1'),
          isPrimary: const Value(true),
          importedAt: DateTime(2026),
          createdAt: DateTime(2026),
        ),
      );
      expect(
        (await series.getSeriesForDive('dive-1')).single.sourceId,
        'src-1',
      );
    },
  );

  test(
    'setPrimaryDataSource promotes the winner series owned by the new primary',
    () async {
      await computer('comp-1');
      await computer('comp-2');
      await dives.createDive(dive('dive-1', const []));
      await source('src-1', 'dive-1', 'comp-1', primary: true);
      await source('src-2', 'dive-1', 'comp-2');
      await series.insertSeries(
        diveId: 'dive-1',
        computerId: 'comp-1',
        sourceId: 'src-1',
        samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
        now: 1000,
      );
      final b = await series.insertSeries(
        diveId: 'dive-1',
        computerId: 'comp-2',
        sourceId: 'src-2',
        isPrimary: false,
        samples: const [ProfileSample(timestamp: 0, depth: 2.0)],
        now: 1000,
      );
      await dives.setPrimaryDataSource(
        diveId: 'dive-1',
        computerReadingId: 'src-2',
      );
      final rows = await series.getSeriesForDive('dive-1');
      expect(rows.where((s) => s.isPrimary).map((s) => s.id), [b]);
      expect((await dives.getDiveProfile('dive-1')).single.depth, 2.0);
    },
  );

  test(
    'setPrimaryDataSource keeps every disjoint segment the winner owns',
    () async {
      await computer('comp-1');
      await computer('comp-2');
      await dives.createDive(dive('dive-1', const []));
      await source('src-1', 'dive-1', 'comp-1', primary: true);
      await source('src-2', 'dive-1', 'comp-2');
      await series.insertSeries(
        diveId: 'dive-1',
        computerId: 'comp-1',
        sourceId: 'src-1',
        samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
        now: 1000,
      );
      // Two segments of comp-2 carrying no source of their own: what a merge
      // of one computer's dive logged in two pieces leaves behind. They cover
      // disjoint time ranges, so neither supersedes the other and both have to
      // stay live.
      final early = await series.insertSeries(
        diveId: 'dive-1',
        computerId: 'comp-2',
        isPrimary: false,
        samples: const [
          ProfileSample(timestamp: 0, depth: 2.0),
          ProfileSample(timestamp: 60, depth: 10.0),
        ],
        now: 1000,
      );
      final tail = await series.insertSeries(
        diveId: 'dive-1',
        computerId: 'comp-2',
        isPrimary: false,
        samples: const [
          ProfileSample(timestamp: 600, depth: 12.0),
          ProfileSample(timestamp: 660, depth: 3.0),
        ],
        now: 1000,
      );

      await dives.setPrimaryDataSource(
        diveId: 'dive-1',
        computerReadingId: 'src-2',
      );

      final rows = await series.getSeriesForDive('dive-1');
      expect(rows.where((s) => s.isPrimary).map((s) => s.id).toSet(), {
        early,
        tail,
      });
      expect((await dives.getDiveProfile('dive-1')).map((p) => p.timestamp), [
        0,
        60,
        600,
        660,
      ]);
    },
  );

  test(
    'setPrimaryDataSource leaves the flags alone when the new primary owns nothing',
    () async {
      await computer('comp-1');
      await computer('comp-2');
      await dives.createDive(dive('dive-1', const []));
      await source('src-1', 'dive-1', 'comp-1', primary: true);
      await source('src-2', 'dive-1', 'comp-2');
      final a = await series.insertSeries(
        diveId: 'dive-1',
        computerId: 'comp-1',
        sourceId: 'src-1',
        samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
        now: 1000,
      );
      await dives.setPrimaryDataSource(
        diveId: 'dive-1',
        computerReadingId: 'src-2',
      );
      expect((await series.getSeriesForDive('dive-1')).single.id, a);
      expect(
        (await series.getSeriesForDive('dive-1')).single.isPrimary,
        isTrue,
      );
    },
  );
}
