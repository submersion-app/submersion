import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart'
    as domain;
import 'package:submersion/features/insights/data/observation_inputs_loader.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  final now = DateTime.utc(2026, 10, 5, 12);
  final june = DateTime.utc(2026, 6, 1, 9);

  setUp(() async {
    db = await setUpTestDatabase();
    await db
        .into(db.divers)
        .insert(
          const DiversCompanion(
            id: Value('A'),
            name: Value('A'),
            createdAt: Value(0),
            updatedAt: Value(0),
          ),
        );
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: const Value('d1'),
            diverId: const Value('A'),
            diveDateTime: Value(june.millisecondsSinceEpoch),
            avgDepth: const Value(20),
            maxDepth: const Value(25),
            runtime: const Value(42 * 60),
            bottomTime: const Value(35 * 60),
            createdAt: const Value(0),
            updatedAt: const Value(0),
          ),
        );
    await db
        .into(db.diveTanks)
        .insert(
          const DiveTanksCompanion(
            id: Value('t1'),
            diveId: Value('d1'),
            startPressure: Value(200),
            endPressure: Value(50),
            volume: Value(11.1),
            o2Percent: Value(21.0),
            hePercent: Value(0.0),
            tankOrder: Value(0),
          ),
        );
    await db
        .into(db.species)
        .insert(
          const SpeciesCompanion(
            id: Value('mola'),
            commonName: Value('Mola'),
            category: Value('fish'),
          ),
        );
    await db
        .into(db.sightings)
        .insert(
          SightingsCompanion.insert(id: 's1', diveId: 'd1', speciesId: 'mola'),
        );
    await ProfileSeriesRepository().insertSeries(
      diveId: 'd1',
      samples: [
        for (var t = 0; t <= 600; t += 10)
          ProfileSample(timestamp: t, depth: t < 300 ? t / 10 : (600 - t) / 10),
      ],
      now: 0,
    );
  });
  tearDown(tearDownTestDatabase);

  test('assembles the whole-log snapshot for one diver', () async {
    final diver = domain.Diver(
      id: 'A',
      name: 'A',
      createdAt: DateTime.utc(2020),
      updatedAt: DateTime.utc(2020),
      priorDiveCount: 40,
      priorDiveTimeSeconds: 3600,
    );
    final inputs = await ObservationInputsLoader().load(
      diverId: 'A',
      diver: diver,
      now: now,
    );
    expect(inputs.now, now);
    expect(inputs.dives.single.id, 'd1');
    expect(inputs.priorDives, 40);
    expect(inputs.priorTimeSeconds, 3600);
    expect(inputs.rmvPerDive.single.diveId, 'd1');
    expect(inputs.rmvPerDive.single.value, greaterThan(0));
    expect(inputs.species.single.name, 'Mola');
    expect(inputs.species.single.firstSeen, june);
    expect(inputs.recentAscentRate, isNotNull);
  });

  test('negative or missing prior experience reads as zero', () async {
    final diver = domain.Diver(
      id: 'A',
      name: 'A',
      createdAt: DateTime.utc(2020),
      updatedAt: DateTime.utc(2020),
      priorDiveCount: -3,
    );
    final inputs = await ObservationInputsLoader().load(
      diverId: 'A',
      diver: diver,
      now: now,
    );
    expect(inputs.priorDives, 0);
    expect(inputs.priorTimeSeconds, 0);
    final noDiver = await ObservationInputsLoader().load(now: now);
    expect(noDiver.priorDives, 0);
  });

  test('a future-dated dive never reaches the rules', () async {
    // A mistyped year must not become "the last dive" (silencing the dive
    // gap) or a record holder (hiding a genuine new record).
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: const Value('typo'),
            diverId: const Value('A'),
            diveDateTime: Value(
              DateTime.utc(2027, 6, 1).millisecondsSinceEpoch,
            ),
            avgDepth: const Value(20),
            maxDepth: const Value(60),
            runtime: const Value(42 * 60),
            createdAt: const Value(0),
            updatedAt: const Value(0),
          ),
        );
    await db
        .into(db.diveTanks)
        .insert(
          const DiveTanksCompanion(
            id: Value('t-typo'),
            diveId: Value('typo'),
            startPressure: Value(200),
            endPressure: Value(50),
            volume: Value(11.1),
            o2Percent: Value(21.0),
            hePercent: Value(0.0),
            tankOrder: Value(0),
          ),
        );
    final inputs = await ObservationInputsLoader().load(diverId: 'A', now: now);
    expect(inputs.dives.map((d) => d.id), ['d1']);
    expect(inputs.rmvPerDive.map((v) => v.diveId), ['d1']);
  });

  test('the ascent rate covers exactly the dives the rules count', () async {
    final before = await ObservationInputsLoader().load(diverId: 'A', now: now);
    // Later today but after now: a whole-day date bound would let this
    // fast ascent into the average while the rules drop the dive itself.
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: const Value('tonight'),
            diverId: const Value('A'),
            diveDateTime: Value(
              now.add(const Duration(hours: 6)).millisecondsSinceEpoch,
            ),
            maxDepth: const Value(30),
            createdAt: const Value(0),
            updatedAt: const Value(0),
          ),
        );
    await ProfileSeriesRepository().insertSeries(
      diveId: 'tonight',
      samples: [
        const ProfileSample(timestamp: 0, depth: 30),
        const ProfileSample(timestamp: 60, depth: 30),
        const ProfileSample(timestamp: 120, depth: 0),
      ],
      now: 0,
    );
    final after = await ObservationInputsLoader().load(diverId: 'A', now: now);
    expect(after.dives.map((d) => d.id), ['d1']);
    expect(after.recentAscentRate, before.recentAscentRate);
  });
}
