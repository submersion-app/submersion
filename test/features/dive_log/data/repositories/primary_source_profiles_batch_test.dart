import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

import '../../../../helpers/test_database.dart';

/// The reduce under test: a top-level function, as the batched read requires
/// of anything it sends to the background isolate.
List<double> depthsOf(List<DiveProfilePoint> points) => [
  for (final p in points) p.depth,
];

/// `reducePrimarySourceProfiles` (issue #3857) against the single-dive read
/// it batches: for every source layout a dive can have, the batch must
/// reduce exactly the samples `getProfilesByDataSource` shows for the
/// primary source, and it must do so in two statements however many dives
/// it is asked for.
void main() {
  late AppDatabase db;
  late DiveRepository repository;

  final now = DateTime.utc(2026, 1, 1).millisecondsSinceEpoch;

  setUp(() async {
    db = await setUpStatementLoggingTestDatabase();
    repository = DiveRepository();
    await withoutStatementLog(() async {
      for (final computer in ['dc-a', 'dc-b']) {
        await db
            .into(db.diveComputers)
            .insert(
              DiveComputersCompanion(
                id: Value(computer),
                name: Value(computer),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );
      }
    });
  });

  tearDown(tearDownTestDatabase);

  Future<void> dive(String id) => db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diveDateTime: Value(now),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

  Future<void> source(
    String id, {
    required String diveId,
    String? computerId,
    required bool isPrimary,
    int day = 1,
  }) => db
      .into(db.diveDataSources)
      .insert(
        DiveDataSourcesCompanion(
          id: Value(id),
          diveId: Value(diveId),
          computerId: Value(computerId),
          isPrimary: Value(isPrimary),
          importedAt: Value(DateTime.utc(2026, 1, day)),
          createdAt: Value(DateTime.utc(2026, 1, day)),
        ),
      );

  Future<void> series(
    String diveId, {
    String? computerId,
    String? sourceId,
    bool isPrimary = true,
    required List<double> depths,
  }) => ProfileSeriesRepository().insertSeries(
    diveId: diveId,
    computerId: computerId,
    sourceId: sourceId,
    isPrimary: isPrimary,
    samples: [
      for (var i = 0; i < depths.length; i++)
        ProfileSample(timestamp: i * 10, depth: depths[i]),
    ],
  );

  /// What the single-dive read shows for [diveId]'s primary source.
  Future<List<double>> primaryBucketOf(String diveId) async {
    final profiles = await repository.getProfilesByDataSource(diveId);
    return depthsOf(profiles.values.firstOrNull?.points ?? const []);
  }

  /// Seeds every source layout the batch must agree with the single-dive
  /// read on, and returns the dive ids.
  Future<List<String>> seedLayouts() => withoutStatementLog(() async {
    // No dive_data_sources row: the primary series stands in for a source,
    // and a demoted copy is left out.
    await dive('legacy');
    await series('legacy', depths: [0, 10, 0]);
    await series('legacy', isPrimary: false, depths: [0, 99, 0]);

    // Two computers: the primary source's series only.
    await dive('two-computers');
    await source(
      'two-a',
      diveId: 'two-computers',
      computerId: 'dc-a',
      isPrimary: true,
    );
    await source(
      'two-b',
      diveId: 'two-computers',
      computerId: 'dc-b',
      isPrimary: false,
      day: 2,
    );
    await series(
      'two-computers',
      computerId: 'dc-a',
      sourceId: 'two-a',
      depths: [0, 20, 0],
    );
    await series(
      'two-computers',
      computerId: 'dc-b',
      sourceId: 'two-b',
      isPrimary: false,
      depths: [0, 40, 0],
    );

    // A saved edit: the edited series replaces the superseded original.
    await dive('edited');
    await source(
      'edited-a',
      diveId: 'edited',
      computerId: 'dc-a',
      isPrimary: true,
    );
    await series(
      'edited',
      computerId: 'dc-a',
      sourceId: 'edited-a',
      isPrimary: false,
      depths: [0, 30, 0],
    );
    await series('edited', sourceId: 'edited-a', depths: [0, 25, 0]);

    // A source row with no series at all.
    await dive('sourced-empty');
    await source(
      'se-a',
      diveId: 'sourced-empty',
      computerId: 'dc-a',
      isPrimary: true,
    );

    // Nothing at all: a manual dive.
    await dive('manual');

    return ['legacy', 'two-computers', 'edited', 'sourced-empty', 'manual'];
  });

  test('reduces exactly the primary bucket the single-dive read shows, for '
      'every id asked', () async {
    final ids = await seedLayouts();

    final batched = await repository.reducePrimarySourceProfiles(ids, depthsOf);

    expect(batched.keys.toSet(), ids.toSet(), reason: 'every id gets an entry');
    for (final id in ids) {
      expect(batched[id], await primaryBucketOf(id), reason: id);
    }
    // The layouts themselves differ, so agreement is not vacuous.
    expect(batched['legacy'], [0, 10, 0]);
    expect(batched['two-computers'], [0, 20, 0]);
    expect(batched['edited'], [0, 25, 0]);
    expect(batched['sourced-empty'], isEmpty);
    expect(batched['manual'], isEmpty);
  });

  test(
    'reads every dive\'s series and sources in one statement each',
    () async {
      final ids = await seedLayouts();

      final logged = <String>[];
      await runZoned(
        () => repository.reducePrimarySourceProfiles(ids, depthsOf),
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) => logged.add(line),
        ),
      );
      final sent = logged.where((l) => l.startsWith('Drift: Sent'));

      expect(
        sent.where((s) => s.contains('dive_profile_series')),
        hasLength(1),
      );
      expect(sent.where((s) => s.contains('dive_data_sources')), hasLength(1));
      expect(sent, hasLength(2));
    },
  );

  test('empty for no ids', () async {
    expect(await repository.reducePrimarySourceProfiles([], depthsOf), isEmpty);
  });
}
