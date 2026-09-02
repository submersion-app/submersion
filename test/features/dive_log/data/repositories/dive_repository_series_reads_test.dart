import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';

import '../../../../helpers/test_database.dart';

/// The series-only read paths. Every profile read comes from
/// `dive_profile_series` rows; a dive with none reads back empty, with no
/// row-table fallback.
void main() {
  late AppDatabase db;
  late DiveRepository dives;
  late ProfileSeriesRepository series;
  const now = 1750000000000;

  setUp(() async {
    db = await setUpTestDatabase();
    dives = DiveRepository();
    series = ProfileSeriesRepository();
    await db
        .into(db.dives)
        .insert(
          const DivesCompanion(
            id: Value('dive-1'),
            diveDateTime: Value(now),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    for (final computer in ['comp-1', 'comp-2']) {
      await db
          .into(db.diveComputers)
          .insert(
            DiveComputersCompanion.insert(
              id: computer,
              name: computer,
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
  });

  tearDown(tearDownTestDatabase);

  Future<void> source(String id, String? computerId, {bool primary = false}) =>
      db
          .into(db.diveDataSources)
          .insert(
            DiveDataSourcesCompanion.insert(
              id: id,
              diveId: 'dive-1',
              computerId: Value(computerId),
              isPrimary: Value(primary),
              importedAt: DateTime.fromMillisecondsSinceEpoch(now),
              createdAt: DateTime.fromMillisecondsSinceEpoch(now),
            ),
          );

  test(
    'getDiveProfile returns only primary series, merged by timestamp',
    () async {
      await series.insertSeries(
        diveId: 'dive-1',
        computerId: 'comp-1',
        samples: const [
          ProfileSample(timestamp: 0, depth: 0.0),
          ProfileSample(timestamp: 20, depth: 10.0),
        ],
        now: now,
      );
      await series.insertSeries(
        diveId: 'dive-1',
        computerId: 'comp-2',
        isPrimary: false,
        samples: const [ProfileSample(timestamp: 10, depth: 99.0)],
        now: now,
      );
      final profile = await dives.getDiveProfile('dive-1');
      expect(profile.map((p) => p.timestamp), [0, 20]);
      expect(profile.map((p) => p.depth), [0.0, 10.0]);
    },
  );

  test(
    'getMergedProfile keeps every source and getDiveById stays in step',
    () async {
      await source('src-1', 'comp-1', primary: true);
      await source('src-2', 'comp-2');
      await series.insertSeries(
        diveId: 'dive-1',
        computerId: 'comp-1',
        sourceId: 'src-1',
        samples: const [
          ProfileSample(timestamp: 0, depth: 0.0),
          ProfileSample(timestamp: 20, depth: 10.0),
        ],
        now: now,
      );
      await series.insertSeries(
        diveId: 'dive-1',
        computerId: 'comp-2',
        sourceId: 'src-2',
        isPrimary: false,
        samples: const [ProfileSample(timestamp: 10, depth: 4.0)],
        now: now,
      );
      final merged = await dives.getMergedProfile('dive-1');
      expect(merged.map((p) => p.timestamp), [0, 10, 20]);
      final byId = await dives.getDiveById('dive-1');
      expect(byId!.profile, merged);
      final analysis = await dives.getDiveForAnalysis('dive-1');
      expect(analysis!.profile, merged);
    },
  );

  test(
    'an edit supersedes the demoted original of the primary family',
    () async {
      await source('src-1', 'comp-1', primary: true);
      await source('src-2', 'comp-2');
      await series.insertSeries(
        diveId: 'dive-1',
        computerId: 'comp-1',
        sourceId: 'src-1',
        isPrimary: false,
        samples: const [
          ProfileSample(timestamp: 0, depth: 0.0),
          ProfileSample(timestamp: 10, depth: 30.0),
        ],
        now: now,
      );
      await series.insertSeries(
        diveId: 'dive-1',
        sourceId: 'src-1',
        samples: const [ProfileSample(timestamp: 0, depth: 0.0)],
        now: now,
      );
      await series.insertSeries(
        diveId: 'dive-1',
        computerId: 'comp-2',
        sourceId: 'src-2',
        isPrimary: false,
        samples: const [ProfileSample(timestamp: 5, depth: 7.0)],
        now: now,
      );
      final merged = await dives.getMergedProfile('dive-1');
      // The trimmed original (30 m at t=10) is gone; the other computer stays.
      expect(merged.map((p) => p.depth), [0.0, 7.0]);
      expect((await dives.getDiveById('dive-1'))!.profile, merged);
    },
  );

  test('a demoted null-computer series next to a computer-owned primary is '
      'kept, as the legacy read keeps it', () async {
    await source('src-1', 'comp-1', primary: true);
    await series.insertSeries(
      diveId: 'dive-1',
      computerId: 'comp-1',
      sourceId: 'src-1',
      samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
      now: now,
    );
    await series.insertSeries(
      diveId: 'dive-1',
      sourceId: 'src-1',
      isPrimary: false,
      samples: const [ProfileSample(timestamp: 5, depth: 2.0)],
      now: now,
    );
    final merged = await dives.getMergedProfile('dive-1');
    expect(merged.map((p) => p.depth), [1.0, 2.0]);
  });

  test('series present but none primary: getDiveProfile is empty, '
      'getMergedProfile keeps the demoted series', () async {
    await series.insertSeries(
      diveId: 'dive-1',
      isPrimary: false,
      samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
      now: now,
    );
    await series.insertSeries(
      diveId: 'dive-1',
      isPrimary: false,
      samples: const [ProfileSample(timestamp: 5, depth: 2.0)],
      now: now,
    );
    expect(await dives.getDiveProfile('dive-1'), isEmpty);
    final merged = await dives.getMergedProfile('dive-1');
    expect(merged.map((p) => p.depth), [1.0, 2.0]);
  });

  test('a dive with no series reads as an empty profile, and a tank with no '
      'series has null start/end pressure', () async {
    await db
        .into(db.diveTanks)
        .insert(DiveTanksCompanion.insert(id: 'tank-a', diveId: 'dive-1'));
    expect(await dives.getDiveProfile('dive-1'), isEmpty);
    expect(await dives.getMergedProfile('dive-1'), isEmpty);
    final dive = await dives.getDiveById('dive-1');
    expect(dive!.profile, isEmpty);
    final tankA = dive.tanks.single;
    expect(tankA.startPressure, isNull);
    expect(tankA.endPressure, isNull);
  });

  test('a dive with no water_temp derives it from the minimum finite sample '
      'temperature in the primary series', () async {
    await series.insertSeries(
      diveId: 'dive-1',
      samples: const [
        ProfileSample(timestamp: 0, depth: 1.0, temperature: 24.0),
        ProfileSample(timestamp: 10, depth: 5.0, temperature: 18.5),
        ProfileSample(timestamp: 20, depth: 3.0, temperature: 20.0),
      ],
      now: now,
    );
    final dive = await dives.getDiveById('dive-1');
    expect(dive!.waterTemp, 18.5);
  });

  test('a sentinel sample temperature is stepped over for the coldest '
      'plausible one', () async {
    // -128 C is what a transmitter or a computer with no thermistor reports.
    // The derived water temperature has always applied the same plausibility
    // band as the import paths (-2 C to 40 C, uddf_import_service) rather
    // than believing it.
    await series.insertSeries(
      diveId: 'dive-1',
      samples: const [
        ProfileSample(timestamp: 0, depth: 1.0, temperature: -128.0),
        ProfileSample(timestamp: 10, depth: 5.0, temperature: 12.5),
        ProfileSample(timestamp: 20, depth: 3.0, temperature: 19.0),
      ],
      now: now,
    );
    final dive = await dives.getDiveById('dive-1');
    expect(dive!.waterTemp, 12.5);
  });

  test('a series whose sample temperatures are all out of band derives no '
      'water temperature', () async {
    await series.insertSeries(
      diveId: 'dive-1',
      samples: const [
        ProfileSample(timestamp: 0, depth: 1.0, temperature: -128.0),
        ProfileSample(timestamp: 10, depth: 5.0, temperature: 99.0),
      ],
      now: now,
    );
    final dive = await dives.getDiveById('dive-1');
    expect(dive!.waterTemp, isNull);
  });

  test(
    'an explicit water_temp is kept even with colder sample temperatures',
    () async {
      await db
          .into(db.dives)
          .insert(
            const DivesCompanion(
              id: Value('dive-2'),
              diveDateTime: Value(now),
              waterTemp: Value(22.0),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await series.insertSeries(
        diveId: 'dive-2',
        samples: const [
          ProfileSample(timestamp: 0, depth: 1.0, temperature: 12.0),
        ],
        now: now,
      );
      final dive = await dives.getDiveById('dive-2');
      expect(dive!.waterTemp, 22.0);
    },
  );

  test('the series is what every profile read returns', () async {
    await series.insertSeries(
      diveId: 'dive-1',
      samples: const [ProfileSample(timestamp: 0, depth: 9.0)],
      now: now,
    );
    expect((await dives.getDiveProfile('dive-1')).single.depth, 9.0);
  });

  test('a series write ticks the detail and analysis watchers', () async {
    final detail = dives.watchDiveDetailChanges().first;
    final analysis = dives.watchAnalysisInputChanges().first;
    await series.insertSeries(
      diveId: 'dive-1',
      samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
      now: now,
    );
    await expectLater(detail, completes);
    await expectLater(analysis, completes);
  });
}
