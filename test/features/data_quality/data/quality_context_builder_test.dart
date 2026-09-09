import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/data_quality/data/services/quality_context_builder.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DiveRepository diveRepo;
  late ProfileSeriesRepository profileSeries;
  late TankPressureSeriesRepository tankSeries;
  late QualityContextBuilder builder;

  setUp(() async {
    db = await setUpTestDatabase();
    diveRepo = DiveRepository();
    profileSeries = ProfileSeriesRepository();
    tankSeries = TankPressureSeriesRepository();
    builder = QualityContextBuilder();
  });
  tearDown(tearDownTestDatabase);

  Future<String> seedDive({
    required String id,
    required DateTime entry,
    Duration runtime = const Duration(minutes: 40),
    String? serial,
    String? diverId,
    List<domain.DiveProfilePoint> profile = const [],
  }) async {
    final dive = domain.Dive(
      id: id,
      dateTime: entry,
      entryTime: entry,
      runtime: runtime,
      maxDepth: 30.0,
      diveComputerSerial: serial,
      diverId: diverId,
      profile: profile,
    );
    await diveRepo.createDive(dive);
    return id;
  }

  test('builds context with sanitized sorted samples', () async {
    final entry = DateTime.utc(2026, 7, 1, 10);
    await seedDive(
      id: 'd1',
      entry: entry,
      profile: [
        const domain.DiveProfilePoint(timestamp: 10, depth: 5.0),
        const domain.DiveProfilePoint(timestamp: 0, depth: 0.0),
      ],
    );
    // A second primary series carrying a non-finite depth sample: the
    // builder must drop it.
    await profileSeries.insertSeries(
      diveId: 'd1',
      samples: const [ProfileSample(timestamp: 20, depth: double.infinity)],
    );
    final ctx = (await builder.buildAll(['d1'])).single;
    expect(ctx.primarySamples.map((s) => s.t), [0, 10]); // sorted, bad dropped
    expect(ctx.dive.id, 'd1');
  });

  group('ppO2MaxBar', () {
    test('defaults to the fixed ceiling with no diver settings', () async {
      await seedDive(id: 'd1', entry: DateTime.utc(2026, 7, 1, 10));
      final ctx = (await builder.buildAll(['d1'])).single;
      expect(ctx.ppO2MaxBar, 1.6);
    });

    test("uses the diver's configured maximum ppO2", () async {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: 'diver-1',
              name: 'Alex Diver',
              createdAt: 1000,
              updatedAt: 1000,
            ),
          );
      await DiverSettingsRepository().createSettingsForDiver(
        'diver-1',
        settings: const AppSettings(ppO2MaxDeco: 1.4),
      );
      await seedDive(
        id: 'd1',
        entry: DateTime.utc(2026, 7, 1, 10),
        diverId: 'diver-1',
      );
      final ctx = (await builder.buildAll(['d1'])).single;
      expect(ctx.ppO2MaxBar, 1.4);
    });
  });

  test(
    'collapses identical samples from same-identity unioned series',
    () async {
      // Two devices packing the same unattributed profile union two primary
      // series of one identity (null computer, null source) after sync. The
      // builder must read them the way the merged profile read does: each
      // duplicated sample counts once, so detectors see no doubled points.
      final entry = DateTime.utc(2026, 7, 2, 10);
      await seedDive(id: 'd2', entry: entry);
      const samples = [
        ProfileSample(timestamp: 0, depth: 0.0),
        ProfileSample(timestamp: 10, depth: 8.0),
      ];
      await profileSeries.insertSeries(diveId: 'd2', samples: samples);
      await profileSeries.insertSeries(diveId: 'd2', samples: samples);

      final ctx = (await builder.buildAll(['d2'])).single;
      expect(ctx.primarySamples.map((s) => s.t), [0, 10]);
    },
  );

  test(
    'builds tank pressures (dropping non-finite) and gas switches',
    () async {
      final entry = DateTime.utc(2026, 7, 1, 10);
      // tank_pressure_series.tankId and gas_switches.tankId both FK to
      // dive_tanks, so the referenced tanks must exist first.
      await diveRepo.createDive(
        domain.Dive(
          id: 'dP',
          dateTime: entry,
          entryTime: entry,
          tanks: const [
            domain.DiveTank(
              id: 'tankA',
              gasMix: domain.GasMix(o2: 21),
              order: 0,
            ),
            domain.DiveTank(
              id: 'tankB',
              gasMix: domain.GasMix(o2: 50),
              order: 1,
            ),
          ],
        ),
      );
      await tankSeries.insertSeries(
        diveId: 'dP',
        tankId: 'tankA',
        samples: const [TankPressureSample(timestamp: 0, pressure: 200.0)],
      );
      // Non-finite pressure must be dropped by the sanitizing loop.
      await tankSeries.insertSeries(
        diveId: 'dP',
        tankId: 'tankA',
        samples: const [
          TankPressureSample(timestamp: 10, pressure: double.infinity),
        ],
      );
      await db
          .into(db.gasSwitches)
          .insert(
            GasSwitchesCompanion.insert(
              id: 'gs1',
              diveId: 'dP',
              timestamp: 300,
              tankId: 'tankB',
              depth: const Value(20.0),
              createdAt: DateTime.utc(2026).millisecondsSinceEpoch,
            ),
          );

      final ctx = (await builder.buildAll(['dP'])).single;
      expect(ctx.pressuresByTankId['tankA'], hasLength(1)); // infinite dropped
      expect(ctx.pressuresByTankId['tankA']!.single.bar, 200.0);
      expect(ctx.gasSwitches.single.tankId, 'tankB');
      expect(ctx.gasSwitches.single.timestamp, 300);
    },
  );

  test("a neighbor's last depth matches the merged profile on an end-timestamp "
      'tie', () async {
    // Two primary series of one dive sharing an end timestamp: the sync
    // union of the same profile from two devices, and the shape the
    // neighbor query's tie-break has to agree with. Series order is
    // (start_timestamp, id), so the LATER-starting series carries the
    // merged profile's last sample even though its id sorts first.
    final entry = DateTime.utc(2026, 7, 1, 10);
    await seedDive(id: 'dA', entry: entry, serial: 'SN-1');
    await seedDive(
      id: 'dB',
      entry: entry.add(const Duration(hours: 1)),
      serial: 'SN-1',
    );
    await profileSeries.insertSeries(
      diveId: 'dB',
      id: 'zz-earlier-start',
      samples: const [
        ProfileSample(timestamp: 0, depth: 4.0),
        ProfileSample(timestamp: 600, depth: 9.0),
      ],
    );
    await profileSeries.insertSeries(
      diveId: 'dB',
      id: 'aa-later-start',
      samples: const [
        ProfileSample(timestamp: 300, depth: 7.0),
        ProfileSample(timestamp: 600, depth: 2.0),
      ],
    );

    final merged = await diveRepo.getMergedProfile('dB');
    final ctx = (await builder.buildAll(['dA'])).single;

    expect(
      ctx.neighbors.single.lastSampleDepth,
      merged.last.depth,
      reason: 'the neighbor query must agree with the merged read',
    );
    expect(ctx.neighbors.single.firstSampleDepth, merged.first.depth);
  });

  test('reports both sides of a pair from the stored sample counts', () async {
    // The duplicate detector picks the richer of two same-computer
    // recordings by sample count, and the pair has ONE canonical finding
    // written by whichever side the scan reached last. Both counts must
    // therefore come from the same stored column: the scanned dive's from
    // its primary series rows, the neighbor's from a subquery over the same
    // table. A non-primary series never counts on either side.
    final entry = DateTime.utc(2026, 7, 1, 10);
    await seedDive(
      id: 'dA',
      entry: entry,
      serial: 'SN-1',
      profile: [
        for (var t = 0; t < 5; t++)
          domain.DiveProfilePoint(timestamp: t * 10, depth: 3.0),
      ],
    );
    await seedDive(
      id: 'dB',
      entry: entry.add(const Duration(minutes: 1)),
      serial: 'SN-1',
      profile: [
        for (var t = 0; t < 3; t++)
          domain.DiveProfilePoint(timestamp: t * 10, depth: 2.0),
      ],
    );
    await profileSeries.insertSeries(
      diveId: 'dB',
      isPrimary: false,
      samples: const [
        ProfileSample(timestamp: 0, depth: 1.0),
        ProfileSample(timestamp: 10, depth: 1.0),
        ProfileSample(timestamp: 20, depth: 1.0),
        ProfileSample(timestamp: 30, depth: 1.0),
      ],
    );

    final ctxA = (await builder.buildAll(['dA'])).single;
    expect(ctxA.primarySampleCount, 5);
    expect(ctxA.neighbors.single.sampleCount, 3);

    final ctxB = (await builder.buildAll(['dB'])).single;
    expect(ctxB.primarySampleCount, 3);
    expect(ctxB.neighbors.single.sampleCount, 5);
  });

  test('a dive with no primary series has an unknown sample count', () async {
    final entry = DateTime.utc(2026, 7, 1, 10);
    await seedDive(id: 'dA', entry: entry, serial: 'SN-1');
    await seedDive(
      id: 'dB',
      entry: entry.add(const Duration(minutes: 1)),
      serial: 'SN-1',
    );
    final ctx = (await builder.buildAll(['dA'])).single;
    expect(ctx.primarySampleCount, isNull);
    expect(ctx.neighbors.single.sampleCount, isNull);
  });

  test(
    'finds same-diver neighbors within the window with edge depths',
    () async {
      final entry = DateTime.utc(2026, 7, 1, 10);
      await seedDive(id: 'dA', entry: entry, serial: 'SN-1');
      await seedDive(
        id: 'dB',
        entry: entry.add(const Duration(hours: 1)),
        serial: 'SN-1',
        profile: [
          const domain.DiveProfilePoint(timestamp: 0, depth: 4.0),
          const domain.DiveProfilePoint(timestamp: 60, depth: 1.5),
        ],
      );
      await seedDive(
        id: 'dFar',
        entry: entry.add(const Duration(days: 2)),
        serial: 'SN-1',
      );
      final ctx = (await builder.buildAll(['dA'])).single;
      expect(ctx.neighbors.map((n) => n.id), ['dB']);
      expect(ctx.neighbors.single.computerSerial, 'SN-1');
      expect(ctx.neighbors.single.firstSampleDepth, 4.0);
      expect(ctx.neighbors.single.lastSampleDepth, 1.5);
    },
  );
}
