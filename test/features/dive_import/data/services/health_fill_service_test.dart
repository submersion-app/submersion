import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/features/dive_import/data/services/health_dive_writer.dart';
import 'package:submersion/features/dive_import/data/services/health_fill_service.dart';
import 'package:submersion/features/dive_import/domain/entities/imported_dive.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';

import '../../../../helpers/test_database.dart';

/// Filling a plan or a draft from an Apple Health workout (issue #637).
void main() {
  late AppDatabase db;
  late DiveRepository dives;
  late HealthFillService service;
  final created = DateTime.utc(2026, 1, 1).millisecondsSinceEpoch;
  final nine = DateTime.utc(2026, 7, 17, 9);

  setUp(() async {
    db = await setUpTestDatabase();
    dives = DiveRepository();
    service = HealthFillService(
      dives: dives,
      writer: HealthDiveWriter(dives: dives),
    );
    for (final id in ['a', 'b']) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: id,
              name: id,
              createdAt: created,
              updatedAt: created,
            ),
          );
    }
  });
  tearDown(tearDownTestDatabase);

  ImportedDive workout(DateTime start) => ImportedDive(
    sourceId: 'w-${start.millisecondsSinceEpoch}',
    source: ImportSource.appleWatch,
    startTime: start,
    endTime: start.add(const Duration(minutes: 45)),
    maxDepth: 18,
    profile: const [],
  );

  /// A plan or a draft at [at], wall clock, with a note and a sketch.
  Future<void> unfilled(
    String id, {
    required DateTime at,
    bool draft = false,
    bool sketch = true,
  }) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: id,
            diverId: const Value('a'),
            diveDateTime: at.millisecondsSinceEpoch,
            entryTime: Value(at.millisecondsSinceEpoch),
            exitTime: Value(
              at.add(const Duration(minutes: 45)).millisecondsSinceEpoch,
            ),
            isPlanned: Value(!draft),
            isDraft: Value(draft),
            notes: const Value('saw a turtle'),
            createdAt: created,
            updatedAt: created,
          ),
        );
    if (sketch) {
      await ProfileSeriesRepository().insertSeries(
        diveId: id,
        samples: const [
          ProfileSample(timestamp: 0, depth: 0),
          ProfileSample(timestamp: 600, depth: 30),
          ProfileSample(timestamp: 2700, depth: 0),
        ],
      );
    }
  }

  Future<List<DiveDataSourcesData>> sourcesOf(String diveId) => (db.select(
    db.diveDataSources,
  )..where((t) => t.diveId.equals(diveId))).get();

  test('a plan made for another time of the day is still filled', () async {
    await unfilled('plan', at: nine);

    final id = await service.fill(
      targetDiveId: 'plan',
      workout: workout(DateTime.utc(2026, 7, 17, 10, 30)),
      diverId: 'a',
    );

    final filled = (await dives.getDiveById(id))!;
    expect(filled.notes, 'saw a turtle');
    expect(filled.isPlanned, isFalse);
    expect(await dives.getDiveById('plan'), isNull);
  });

  test('a fill that fails writes nothing and leaves the plan whole', () async {
    await unfilled('plan', at: nine);

    await expectLater(
      service.fill(targetDiveId: 'plan', workout: workout(nine), diverId: 'b'),
      throwsA(anything),
    );

    expect((await dives.getDiveById('plan'))!.isPlanned, isTrue);
    expect(
      await ProfileSeriesRepository().getSeriesForDive('plan'),
      isNotEmpty,
    );
    expect((await db.select(db.dives).get()).map((d) => d.id), ['plan']);
  });

  test('a filled draft has the watch as its only source, and no sketch '
      'as readings', () async {
    await unfilled('draft', at: nine, draft: true);

    final id = await service.fill(
      targetDiveId: 'draft',
      workout: workout(nine),
      diverId: 'a',
    );

    expect(await sourcesOf(id), hasLength(1));
    final series = await ProfileSeriesRepository().getSeriesForDive(id);
    expect(series.where((s) => s.samples.any((p) => p.depth == 30)), isEmpty);
  });

  test('the draft\'s tide record moves to the filled dive', () async {
    await unfilled('draft', at: nine, draft: true, sketch: false);
    await db
        .into(db.tideRecords)
        .insert(
          TideRecordsCompanion.insert(
            id: 'tide1',
            diveId: 'draft',
            heightMeters: 1.0,
            tideState: 'rising',
            createdAt: created,
          ),
        );

    final id = await service.fill(
      targetDiveId: 'draft',
      workout: workout(nine),
      diverId: 'a',
    );

    final tides = await db.select(db.tideRecords).get();
    expect(tides.map((t) => (t.id, t.diveId)), [('tide1', id)]);
  });
}
