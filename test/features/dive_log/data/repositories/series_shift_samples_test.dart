import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ProfileSeriesRepository profiles;
  late TankPressureSeriesRepository pressures;

  setUp(() async {
    db = await setUpTestDatabase();
    profiles = ProfileSeriesRepository();
    pressures = TankPressureSeriesRepository();
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'dive-1',
            diveDateTime: 1,
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await db
        .into(db.diveTanks)
        .insert(
          const DiveTanksCompanion(
            id: Value('tank-1'),
            diveId: Value('dive-1'),
            tankOrder: Value(0),
          ),
        );
  });

  tearDown(tearDownTestDatabase);

  group('ProfileSeriesRepository.shiftSamples', () {
    test('moves every sample and the stored span, and nothing else', () async {
      final id = await profiles.insertSeries(
        diveId: 'dive-1',
        samples: const [
          ProfileSample(timestamp: 120, depth: 0, temperature: 24),
          ProfileSample(timestamp: 420, depth: 20, temperature: 18),
        ],
        activatedAt: const Value(5),
        now: 1000,
      );

      await profiles.shiftSamples(
        await profiles.getSeriesForDive('dive-1'),
        -120,
        now: 2000,
      );

      final moved = (await profiles.getSeriesById(id))!;
      expect(moved.samples.map((p) => p.timestamp), [0, 300]);
      expect(moved.samples.map((p) => p.temperature), [24, 18]);
      expect(moved.isPrimary, isTrue);
      expect(moved.activatedAt, 5);
      final row = await (db.select(
        db.diveProfileSeries,
      )..where((t) => t.id.equals(id))).getSingle();
      expect(row.startTimestamp, 0);
      expect(row.endTimestamp, 300);
      expect(row.updatedAt, 2000);
    });

    test('keeps the revision lineage and refreshes its fingerprint', () async {
      final original = await profiles.insertSeries(
        diveId: 'dive-1',
        samples: const [ProfileSample(timestamp: 120, depth: 10)],
        now: 1000,
      );
      final edit = await profiles.insertSeries(
        diveId: 'dive-1',
        samples: const [ProfileSample(timestamp: 120, depth: 12)],
        parentSeriesId: original,
        revisionKind: 'edit',
        now: 1001,
      );
      final before = await profiles.getRevisionsForDive('dive-1');

      await profiles.shiftSamples(
        await profiles.getSeriesForDive('dive-1'),
        -120,
        now: 2000,
      );

      expect(await profiles.parentSeriesIdOf(edit), original);
      final after = await profiles.getRevisionsForDive('dive-1');
      expect(after, hasLength(before.length));
      expect(
        after.map((r) => r.contentHash).toSet(),
        isNot(anyElement(isIn(before.map((r) => r.contentHash)))),
      );
    });

    test('restamps the row so sync carries the new blob', () async {
      final id = await profiles.insertSeries(
        diveId: 'dive-1',
        samples: const [ProfileSample(timestamp: 120, depth: 10)],
        now: 1000,
      );
      final before = (await profiles.getSeriesById(id))!.hlc;

      await profiles.shiftSamples(
        await profiles.getSeriesForDive('dive-1'),
        -120,
        now: 2000,
      );

      expect((await profiles.getSeriesById(id))!.hlc, isNot(before));
    });

    test('a zero shift writes nothing', () async {
      final id = await profiles.insertSeries(
        diveId: 'dive-1',
        samples: const [ProfileSample(timestamp: 120, depth: 10)],
        now: 1000,
      );

      await profiles.shiftSamples(
        await profiles.getSeriesForDive('dive-1'),
        0,
        now: 2000,
      );

      final row = await (db.select(
        db.diveProfileSeries,
      )..where((t) => t.id.equals(id))).getSingle();
      expect(row.updatedAt, 1000);
    });
  });

  group('TankPressureSeriesRepository.shiftSamples', () {
    test('moves every sample and the stored span, keeping the id', () async {
      final id = await pressures.insertSeries(
        diveId: 'dive-1',
        tankId: 'tank-1',
        samples: const [
          TankPressureSample(timestamp: 120, pressure: 200),
          TankPressureSample(timestamp: 720, pressure: 80),
        ],
        now: 1000,
      );
      final before = (await pressures.getSeriesForDive('dive-1')).single.hlc;

      await pressures.shiftSamples(
        await pressures.getSeriesForDive('dive-1'),
        -120,
        now: 2000,
      );

      final moved = (await pressures.getSeriesForDive('dive-1')).single;
      expect(moved.id, id);
      expect(moved.samples.map((p) => p.timestamp), [0, 600]);
      expect(moved.samples.map((p) => p.pressure), [200, 80]);
      expect(moved.summary.startTimestamp, 0);
      expect(moved.summary.endTimestamp, 600);
      expect(moved.updatedAt, 2000);
      expect(moved.hlc, isNot(before));
    });

    test('a zero shift writes nothing', () async {
      await pressures.insertSeries(
        diveId: 'dive-1',
        tankId: 'tank-1',
        samples: const [TankPressureSample(timestamp: 120, pressure: 200)],
        now: 1000,
      );

      await pressures.shiftSamples(
        await pressures.getSeriesForDive('dive-1'),
        0,
        now: 2000,
      );

      final kept = (await pressures.getSeriesForDive('dive-1')).single;
      expect(kept.updatedAt, 1000);
    });
  });
}
