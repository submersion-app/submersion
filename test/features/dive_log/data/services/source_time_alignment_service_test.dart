import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';
import 'package:submersion/features/dive_log/data/services/source_time_alignment_service.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../../../helpers/test_database.dart';

/// A multilevel reef dive sampled every 10 s, from its own start.
List<(int, double)> reefTrace() {
  const knots = <(int, double)>[
    (0, 0),
    (120, 18),
    (240, 22),
    (600, 21),
    (900, 16),
    (1300, 14),
    (1700, 10),
    (2200, 8),
    (2400, 5),
    (2580, 5),
    (2760, 4.8),
    (2880, 0),
  ];
  double at(int t) {
    for (var i = 1; i < knots.length; i++) {
      final (t0, d0) = knots[i - 1];
      final (t1, d1) = knots[i];
      if (t <= t1) return d0 + (d1 - d0) * (t - t0) / (t1 - t0);
    }
    return 0;
  }

  return [for (var t = 0; t <= 2880; t += 10) (t, at(t))];
}

void main() {
  late AppDatabase db;
  late DiveRepository diveRepo;
  late ProfileSeriesRepository profileSeries;
  late TankPressureSeriesRepository tankSeries;
  late SourceTimeAlignmentService service;

  final entry = DateTime.utc(2026, 9, 14, 9);
  const diveId = 'dive1';
  const primarySource = 'srcA';
  const secondarySource = 'srcB';
  const primaryComputer = 'compA';
  const secondaryComputer = 'compB';

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement('PRAGMA foreign_keys = OFF');
    diveRepo = DiveRepository();
    profileSeries = ProfileSeriesRepository();
    tankSeries = TankPressureSeriesRepository();
    service = SourceTimeAlignmentService();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> insertSource(
    String id, {
    required String computerId,
    required bool isPrimary,
    int? offset,
  }) => db
      .into(db.diveDataSources)
      .insert(
        DiveDataSourcesCompanion.insert(
          id: id,
          diveId: diveId,
          computerId: Value(computerId),
          isPrimary: Value(isPrimary),
          entryTime: Value(entry),
          timeOffsetSeconds: Value(offset),
          importedAt: entry,
          createdAt: entry,
        ),
      );

  /// One dive from two computers. The secondary's samples, events and gas
  /// switch were placed [storedOffset] seconds late although both computers
  /// started together: its clock had drifted.
  Future<void> seedConsolidatedDive({int storedOffset = 100}) async {
    await diveRepo.createDive(
      domain.Dive(
        id: diveId,
        diverId: 'diver1',
        dateTime: entry,
        entryTime: entry,
        runtime: const Duration(minutes: 48),
        maxDepth: 22,
        profile: [
          for (final (t, d) in reefTrace())
            domain.DiveProfilePoint(timestamp: t, depth: d),
        ],
      ),
    );
    await insertSource(
      primarySource,
      computerId: primaryComputer,
      isPrimary: true,
    );
    await insertSource(
      secondarySource,
      computerId: secondaryComputer,
      isPrimary: false,
      offset: storedOffset,
    );
    await profileSeries.insertSeries(
      diveId: diveId,
      computerId: secondaryComputer,
      sourceId: secondarySource,
      isPrimary: false,
      samples: [
        for (final (t, d) in reefTrace())
          ProfileSample(timestamp: t + storedOffset, depth: d + 0.3),
      ],
    );
    await db
        .into(db.diveTanks)
        .insert(DiveTanksCompanion.insert(id: 'tankB', diveId: diveId));
    await tankSeries.insertSeries(
      diveId: diveId,
      tankId: 'tankB',
      computerId: secondaryComputer,
      sourceId: secondarySource,
      samples: [
        TankPressureSample(timestamp: storedOffset, pressure: 200),
        TankPressureSample(timestamp: 2880 + storedOffset, pressure: 60),
      ],
    );
    for (final (id, computer, t) in [
      ('evA', primaryComputer, 600),
      ('evB', secondaryComputer, 600 + storedOffset),
    ]) {
      await db
          .into(db.diveProfileEvents)
          .insert(
            DiveProfileEventsCompanion.insert(
              id: id,
              diveId: diveId,
              timestamp: t,
              eventType: 'bookmark',
              computerId: Value(computer),
              createdAt: 0,
            ),
          );
    }
    await db
        .into(db.gasSwitches)
        .insert(
          GasSwitchesCompanion.insert(
            id: 'gsB',
            diveId: diveId,
            timestamp: 1200 + storedOffset,
            tankId: 'tankB',
            computerId: const Value(secondaryComputer),
            createdAt: 0,
          ),
        );
  }

  Future<int?> storedOffsetOf(String sourceId) async => (await (db.select(
    db.diveDataSources,
  )..where((t) => t.id.equals(sourceId))).getSingle()).timeOffsetSeconds;

  group('check', () {
    test('reports the depth fit against the stored offset', () async {
      await seedConsolidatedDive();
      final checks = await service.check(diveId);
      expect(checks, hasLength(1));
      final c = checks.single;
      expect(c.sourceId, secondarySource);
      expect(c.storedOffsetSeconds, 100);
      expect(c.fit.offsetSeconds, 0);
      expect(c.fit.isStrongMatch, isTrue);
      expect(c.isMisaligned, isTrue);
    });

    test('a source within the tolerance is not misaligned', () async {
      await seedConsolidatedDive(storedOffset: 3);
      final c = (await service.check(diveId)).single;
      expect(c.isMisaligned, isFalse);
    });

    test('a dive with one source has nothing to check', () async {
      await seedConsolidatedDive();
      await (db.delete(
        db.diveDataSources,
      )..where((t) => t.id.equals(secondarySource))).go();
      expect(await service.check(diveId), isEmpty);
    });
  });

  group('setOffset', () {
    test(
      'moves everything the source recorded and records the offset',
      () async {
        await seedConsolidatedDive();
        await service.setOffset(
          diveId: diveId,
          sourceId: secondarySource,
          offsetSeconds: 0,
        );

        expect(await storedOffsetOf(secondarySource), 0);

        final series = await profileSeries.getSeriesForDive(diveId);
        final secondary = series.singleWhere(
          (s) => s.sourceId == secondarySource,
        );
        expect(secondary.samples.first.timestamp, 0);
        expect(secondary.summary.startTimestamp, 0);
        expect(secondary.isPrimary, isFalse);
        expect(secondary.computerId, secondaryComputer);
        final primary = series.singleWhere(
          (s) => s.sourceId != secondarySource,
        );
        expect(primary.samples.first.timestamp, 0);

        final pressures = await tankSeries.getSeriesForDive(diveId);
        expect(pressures.single.samples.first.timestamp, 0);
        expect(pressures.single.sourceId, secondarySource);

        final events = {
          for (final e in await db.select(db.diveProfileEvents).get())
            e.id: e.timestamp,
        };
        expect(events, {'evA': 600, 'evB': 600});
        final gasSwitch = await db.select(db.gasSwitches).getSingle();
        expect(gasSwitch.timestamp, 1200);
      },
    );

    test('a nudge composes with the stored offset', () async {
      await seedConsolidatedDive();
      final previous = await service.setOffset(
        diveId: diveId,
        sourceId: secondarySource,
        offsetSeconds: 97,
      );
      expect(previous, 100);
      expect(await storedOffsetOf(secondarySource), 97);
      final secondary = (await profileSeries.getSeriesForDive(
        diveId,
      )).singleWhere((s) => s.sourceId == secondarySource);
      expect(secondary.samples.first.timestamp, 97);
    });

    test('marks the moved rows for sync', () async {
      await seedConsolidatedDive();
      await service.setOffset(
        diveId: diveId,
        sourceId: secondarySource,
        offsetSeconds: 0,
      );
      final pending = await db.select(db.syncRecords).get();
      final byType = <String, Set<String>>{};
      for (final r in pending) {
        byType.putIfAbsent(r.entityType, () => {}).add(r.recordId);
      }
      expect(byType['diveDataSources'], contains(secondarySource));
      expect(byType['diveProfileEvents'], contains('evB'));
      expect(byType['diveProfileEvents'], isNot(contains('evA')));
      expect(byType['gasSwitches'], contains('gsB'));
      expect(byType['dives'], contains(diveId));
    });

    test('the primary source cannot be moved', () async {
      await seedConsolidatedDive();
      await expectLater(
        service.setOffset(
          diveId: diveId,
          sourceId: primarySource,
          offsetSeconds: 10,
        ),
        throwsArgumentError,
      );
    });

    test('a source of another dive is refused', () async {
      await seedConsolidatedDive();
      await expectLater(
        service.setOffset(
          diveId: 'other',
          sourceId: secondarySource,
          offsetSeconds: 0,
        ),
        throwsArgumentError,
      );
    });

    test('the same offset writes nothing', () async {
      await seedConsolidatedDive();
      final before = await profileSeries.getSeriesForDive(diveId);
      await service.setOffset(
        diveId: diveId,
        sourceId: secondarySource,
        offsetSeconds: 100,
      );
      final after = await profileSeries.getSeriesForDive(diveId);
      expect(after.map((s) => s.id), before.map((s) => s.id));
    });
  });

  group('placeReimported', () {
    /// What a Replace Source leaves behind: the secondary's samples back on
    /// its own timeline, with no stored offset.
    Future<void> reimportSecondary({List<(int, double)>? trace}) async {
      await profileSeries.deleteByIds([
        for (final s in await profileSeries.getSeriesForDive(diveId))
          if (s.sourceId == secondarySource) s.id,
      ]);
      await (db.update(
        db.diveDataSources,
      )..where((t) => t.id.equals(secondarySource))).write(
        const DiveDataSourcesCompanion(timeOffsetSeconds: Value(null)),
      );
      await profileSeries.insertSeries(
        diveId: diveId,
        computerId: secondaryComputer,
        sourceId: secondarySource,
        isPrimary: false,
        samples: [
          for (final (t, d) in trace ?? reefTrace())
            ProfileSample(timestamp: t, depth: d),
        ],
      );
    }

    Future<int> secondaryStart() async =>
        (await profileSeries.getSeriesForDive(diveId))
            .singleWhere((s) => s.sourceId == secondarySource)
            .samples
            .first
            .timestamp;

    test('reads the stored offset of a secondary computer', () async {
      await seedConsolidatedDive();
      expect(await service.secondaryOffsetOf(diveId, secondaryComputer), 100);
      expect(await service.secondaryOffsetOf(diveId, primaryComputer), isNull);
    });

    test('a strong fit that disagrees with the old offset wins', () async {
      await seedConsolidatedDive();
      await reimportSecondary();
      await service.placeReimported(
        diveId: diveId,
        computerId: secondaryComputer,
        previousOffsetSeconds: 100,
      );
      // Already on its own timeline, which is where the fit puts it; a null
      // offset reads as 0 everywhere.
      expect(await storedOffsetOf(secondarySource) ?? 0, 0);
      expect(await secondaryStart(), 0);
    });

    test('an old offset within the tolerance of the fit is kept', () async {
      await seedConsolidatedDive(storedOffset: 3);
      await reimportSecondary();
      await service.placeReimported(
        diveId: diveId,
        computerId: secondaryComputer,
        previousOffsetSeconds: 3,
      );
      expect(await storedOffsetOf(secondarySource), 3);
      expect(await secondaryStart(), 3);
    });

    test('without a usable fit the old offset is restored', () async {
      await seedConsolidatedDive();
      await reimportSecondary(
        trace: [for (var t = 0; t <= 2880; t += 10) (t, t == 0 ? 0.0 : 3.0)],
      );
      await service.placeReimported(
        diveId: diveId,
        computerId: secondaryComputer,
        previousOffsetSeconds: 100,
      );
      expect(await storedOffsetOf(secondarySource), 100);
      expect(await secondaryStart(), 100);
    });
  });
}
