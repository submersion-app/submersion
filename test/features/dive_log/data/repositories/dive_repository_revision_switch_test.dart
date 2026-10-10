import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../../../helpers/test_database.dart';

/// The Edit Profile revision dropdown switches the live profile through
/// [DiveRepository.setActiveProfileSeries]. On a dive with more than one
/// computer, the series flag and the data-source flag must keep naming the
/// same computer (issue #3067).
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
    String? computerId, {
    bool primary = false,
    String? model,
  }) async {
    final now = DateTime.now();
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion.insert(
            id: id,
            diveId: 'dive-1',
            computerId: Value(computerId),
            computerModel: Value(model),
            isPrimary: Value(primary),
            importedAt: now,
            createdAt: now,
          ),
        );
  }

  Future<Set<String>> primarySources() async {
    final rows =
        await (db.select(db.diveDataSources)..where(
              (t) => t.diveId.equals('dive-1') & t.isPrimary.equals(true),
            ))
            .get();
    return {for (final row in rows) row.id};
  }

  Future<Set<String>> primarySeries() async => {
    for (final s in await series.getSeriesForDive('dive-1'))
      if (s.isPrimary) s.id,
  };

  late String seriesA;
  late String seriesB;

  setUp(() async {
    db = await setUpTestDatabase();
    dives = DiveRepository();
    series = ProfileSeriesRepository();

    await computer('comp-1');
    await computer('comp-2');
    await dives.createDive(
      domain.Dive(id: 'dive-1', dateTime: DateTime(2026, 1, 1)),
    );
    await source('src-1', 'comp-1', primary: true, model: 'Perdix');
    await source('src-2', 'comp-2', model: 'Teric');
    seriesA = await series.insertSeries(
      diveId: 'dive-1',
      computerId: 'comp-1',
      sourceId: 'src-1',
      revisionKind: 'computer_import',
      samples: const [
        ProfileSample(timestamp: 0, depth: 0.0),
        ProfileSample(timestamp: 60, depth: 20.0),
      ],
      now: 1000,
    );
    seriesB = await series.insertSeries(
      diveId: 'dive-1',
      computerId: 'comp-2',
      sourceId: 'src-2',
      isPrimary: false,
      revisionKind: 'computer_import',
      samples: const [
        ProfileSample(timestamp: 0, depth: 0.0),
        ProfileSample(timestamp: 60, depth: 22.0),
      ],
      now: 1000,
    );
  });

  tearDown(tearDownTestDatabase);

  test('switching to another computer revision makes that computer the '
      'primary data source too', () async {
    await dives.setActiveProfileSeries('dive-1', seriesB);

    expect(await primarySeries(), {seriesB});
    expect(await primarySources(), {'src-2'});
    final dive = await (db.select(
      db.dives,
    )..where((t) => t.id.equals('dive-1'))).getSingle();
    expect(dive.diveComputerModel, 'Teric');
    expect(dive.maxDepth, 22.0);
  });

  test('switching to an edit of another computer makes that computer the '
      'primary data source too', () async {
    await dives.setPrimaryDataSource(
      diveId: 'dive-1',
      computerReadingId: 'src-2',
    );
    await dives.saveEditedProfile('dive-1', const [
      domain.DiveProfilePoint(timestamp: 0, depth: 0.0),
      domain.DiveProfilePoint(timestamp: 60, depth: 21.0),
    ]);
    final edit = (await primarySeries()).single;
    await dives.setPrimaryDataSource(
      diveId: 'dive-1',
      computerReadingId: 'src-1',
    );
    expect(await primarySeries(), {seriesA});

    await dives.setActiveProfileSeries('dive-1', edit);

    expect(await primarySeries(), {edit});
    expect(await primarySources(), {'src-2'});
  });

  test('switching to a revision of the primary computer leaves the data '
      'sources alone', () async {
    await dives.saveEditedProfile('dive-1', const [
      domain.DiveProfilePoint(timestamp: 0, depth: 0.0),
      domain.DiveProfilePoint(timestamp: 60, depth: 19.0),
    ]);

    await dives.setActiveProfileSeries('dive-1', seriesA);

    expect(await primarySeries(), {seriesA});
    expect(await primarySources(), {'src-1'});
  });

  test(
    'switching to a series no source owns leaves the data sources alone',
    () async {
      final legacy = await series.insertSeries(
        diveId: 'dive-1',
        isPrimary: false,
        revisionKind: 'legacy',
        samples: const [ProfileSample(timestamp: 0, depth: 5.0)],
        now: 1000,
      );

      await dives.setActiveProfileSeries('dive-1', legacy);

      expect(await primarySeries(), {legacy});
      expect(await primarySources(), {'src-1'});
    },
  );

  test(
    'profile history names the source and computer of each revision',
    () async {
      final history = await dives.getProfileHistory('dive-1');
      final byId = {for (final r in history) r.seriesId: r};

      expect(byId[seriesA]?.sourceId, 'src-1');
      expect(byId[seriesA]?.computerId, 'comp-1');
      expect(byId[seriesB]?.sourceId, 'src-2');
      expect(byId[seriesB]?.computerId, 'comp-2');
    },
  );
}
