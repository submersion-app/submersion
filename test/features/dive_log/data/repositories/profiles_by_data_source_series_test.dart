import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';

import '../../../../helpers/test_database.dart';

/// getProfilesByDataSource built from richer, multi-sample series; mirrors
/// the per-sample-series cases profiles_by_data_source_test pins.
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
    'series attribute to their source, null-computer series to the primary',
    () async {
      await source('src-1', 'comp-1', primary: true);
      await source('src-2', 'comp-2');
      await series.insertSeries(
        diveId: 'dive-1',
        computerId: 'comp-1',
        sourceId: 'src-1',
        samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
        now: now,
      );
      await series.insertSeries(
        diveId: 'dive-1',
        computerId: 'comp-2',
        sourceId: 'src-2',
        isPrimary: false,
        samples: const [ProfileSample(timestamp: 0, depth: 2.0)],
        now: now,
      );
      // A pre-v154 series: no source, no computer.
      await series.insertSeries(
        diveId: 'dive-1',
        samples: const [ProfileSample(timestamp: 5, depth: 3.0)],
        now: now,
      );
      final bySource = await dives.getProfilesByDataSource('dive-1');
      expect(bySource.keys.toSet(), {'src-1', 'src-2'});
      expect(bySource['src-1']!.points.map((p) => p.depth), [1.0, 3.0]);
      expect(bySource['src-2']!.points.map((p) => p.depth), [2.0]);
      expect(bySource['src-1']!.isEdited, isFalse);
    },
  );

  test('an edited primary replaces the original and sets isEdited', () async {
    await source('src-1', 'comp-1', primary: true);
    await series.insertSeries(
      diveId: 'dive-1',
      computerId: 'comp-1',
      sourceId: 'src-1',
      isPrimary: false,
      samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
      now: now,
    );
    await series.insertSeries(
      diveId: 'dive-1',
      sourceId: 'src-1',
      samples: const [ProfileSample(timestamp: 0, depth: 9.0)],
      now: now,
    );
    final bySource = await dives.getProfilesByDataSource('dive-1');
    expect(bySource['src-1']!.isEdited, isTrue);
    expect(bySource['src-1']!.points.single.depth, 9.0);
  });

  test('a metadata-only source keeps an entry with no points', () async {
    await source('src-1', 'comp-1', primary: true);
    await source('src-2', 'comp-2');
    await series.insertSeries(
      diveId: 'dive-1',
      computerId: 'comp-1',
      sourceId: 'src-1',
      samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
      now: now,
    );
    final bySource = await dives.getProfilesByDataSource('dive-1');
    expect(bySource['src-2']!.points, isEmpty);
  });

  test('with no data sources a synthetic primary source is produced', () async {
    await series.insertSeries(
      diveId: 'dive-1',
      computerId: 'comp-1',
      samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
      now: now,
    );
    await series.insertSeries(
      diveId: 'dive-1',
      computerId: 'comp-1',
      isPrimary: false,
      samples: const [ProfileSample(timestamp: 0, depth: 2.0)],
      now: now,
    );
    final bySource = await dives.getProfilesByDataSource('dive-1');
    final only = bySource.values.single;
    expect(only.sourceId, legacyDataSourceId('dive-1'));
    expect(only.computerId, 'comp-1');
    expect(only.isEdited, isTrue);
    expect(only.points.single.depth, 1.0);
  });

  test('no series and no data sources gives an empty map', () async {
    expect(await dives.getProfilesByDataSource('dive-1'), isEmpty);
  });

  test(
    'sources exist but carry no series: one empty entry per source',
    () async {
      await source('src-1', 'comp-1', primary: true);
      await source('src-2', 'comp-2');
      final bySource = await dives.getProfilesByDataSource('dive-1');
      expect(bySource.keys.toSet(), {'src-1', 'src-2'});
      expect(bySource['src-1']!.points, isEmpty);
      expect(bySource['src-2']!.points, isEmpty);
      expect(bySource['src-1']!.isEdited, isFalse);
    },
  );
}
