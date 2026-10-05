import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/insights/data/repositories/observation_inputs_queries.dart';
import 'package:submersion/features/insights/domain/observations/observation_inputs.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  final jan10 = DateTime.utc(2026, 1, 10, 9);
  final feb1 = DateTime.utc(2026, 2, 1, 9);

  Future<void> diver(String id) => db
      .into(db.divers)
      .insert(
        DiversCompanion(
          id: Value(id),
          name: Value(id),
          createdAt: const Value(0),
          updatedAt: const Value(0),
        ),
      );

  Future<void> diveRow(
    String id, {
    String diverId = 'A',
    required DateTime when,
    String? siteId,
    double? maxDepth,
    int? runtime,
    int? entry,
    int? exit,
    bool excluded = false,
    bool planned = false,
  }) => db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diverId: Value(diverId),
          siteId: Value(siteId),
          diveDateTime: Value(when.millisecondsSinceEpoch),
          maxDepth: Value(maxDepth),
          runtime: Value(runtime),
          entryTime: Value(entry),
          exitTime: Value(exit),
          excludedFromStats: Value(excluded),
          isPlanned: Value(planned),
          createdAt: const Value(0),
          updatedAt: const Value(0),
        ),
      );

  setUp(() async {
    db = await setUpTestDatabase();
    await diver('A');
    await diver('B');
    await db
        .into(db.diveSites)
        .insert(
          const DiveSitesCompanion(
            id: Value('site-1'),
            diverId: Value('A'),
            name: Value('Blue Hole'),
            country: Value('Egypt'),
            createdAt: Value(0),
            updatedAt: Value(0),
          ),
        );
    await db
        .into(db.buddies)
        .insert(
          const BuddiesCompanion(
            id: Value('sam'),
            diverId: Value('A'),
            name: Value('Sam'),
            createdAt: Value(0),
            updatedAt: Value(0),
          ),
        );
    await diveRow(
      'd1',
      when: jan10,
      siteId: 'site-1',
      maxDepth: 24,
      runtime: 3000,
    );
    final entry = feb1.millisecondsSinceEpoch;
    await diveRow('d2', when: feb1, entry: entry, exit: entry + 2400 * 1000);
    await diveRow('x', when: jan10, excluded: true);
    await diveRow('p', when: jan10, planned: true);
    await diveRow('o', diverId: 'B', when: jan10);
    for (final (k, kg) in [(1, 3.0), (2, 3.0)]) {
      await db
          .into(db.diveWeights)
          .insert(
            DiveWeightsCompanion(
              id: Value('w$k'),
              diveId: const Value('d1'),
              weightType: const Value('Belt'),
              amountKg: Value(kg),
              createdAt: const Value(0),
            ),
          );
    }
    for (final (k, role) in [(1, 'buddy'), (2, 'instructor')]) {
      await db
          .into(db.diveBuddies)
          .insert(
            DiveBuddiesCompanion(
              id: Value('db$k'),
              diveId: const Value('d1'),
              buddyId: const Value('sam'),
              role: Value(role),
              createdAt: const Value(0),
            ),
          );
    }
    await ProfileSeriesRepository().insertSeries(
      diveId: 'd1',
      samples: [
        const ProfileSample(timestamp: 0, depth: 0),
        const ProfileSample(timestamp: 600, depth: 20),
      ],
      now: 0,
    );
  });
  tearDown(tearDownTestDatabase);

  test('one row per in-scope dive of the diver, oldest first', () async {
    final dives = await ObservationInputsQueries().dives(diverId: 'A');
    expect(dives.map((d) => d.id), ['d1', 'd2']);

    final d1 = dives.first;
    expect(d1.date, jan10);
    expect(d1.maxDepthM, 24);
    expect(d1.runtimeSeconds, 3000);
    expect(d1.weightKg, 6);
    expect(d1.siteId, 'site-1');
    expect(d1.siteName, 'Blue Hole');
    expect(d1.country, 'Egypt');
    expect(d1.hasProfile, isTrue);
    expect(d1.buddies, const [ObservationBuddy(id: 'sam', name: 'Sam')]);

    final d2 = dives.last;
    expect(d2.runtimeSeconds, 2400, reason: 'from the entry and exit times');
    expect(d2.weightKg, isNull);
    expect(d2.siteId, isNull);
    expect(d2.hasProfile, isFalse);
    expect(d2.buddies, isEmpty);
  });

  test('a null diver reads every diver', () async {
    final dives = await ObservationInputsQueries().dives();
    expect(dives.map((d) => d.id), unorderedEquals(['d1', 'd2', 'o']));
  });
}
