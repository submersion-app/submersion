import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart'
    show AppDatabase, GasSwitchesCompanion;
import 'package:submersion/features/dive_log/data/repositories/derived_metrics_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';
import 'package:submersion/features/dive_log/data/services/derived_metrics_worker.dart';
import 'package:submersion/features/dive_log/data/services/gas_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/services/gas_use_window.dart';

import '../../../../helpers/test_database.dart';

/// Issue #2930: surface time a switch logged on the surface or a pressure
/// still falling there says a cylinder was breathed in reaches the detail
/// read, the list read and SAC by cylinder alike.
void main() {
  late DiveRepository repository;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
  });
  tearDown(() async => tearDownTestDatabase());

  // Two minutes on the surface, 18 m to 30 minutes, then ten more on the
  // surface.
  final profile = [
    for (var t = 0; t <= 40 * 60; t += 10)
      domain.DiveProfilePoint(
        timestamp: t,
        depth: t < 2 * 60 || t > 30 * 60 ? 0.3 : 18,
      ),
  ];

  Future<void> createDive(List<domain.DiveTank> tanks) => repository.createDive(
    domain.Dive(
      id: 'd',
      dateTime: DateTime.utc(2026, 5, 1, 10),
      runtime: const Duration(minutes: 40),
      avgDepth: 14,
      tanks: tanks,
      profile: profile,
    ),
  );

  Future<void> insertSwitch(String tankId, int timestamp) => db
      .into(db.gasSwitches)
      .insert(
        GasSwitchesCompanion(
          id: Value('sw-$tankId-$timestamp'),
          diveId: const Value('d'),
          tankId: Value(tankId),
          timestamp: Value(timestamp),
          createdAt: const Value(0),
        ),
      );

  Future<void> sweep() => DerivedMetricsRepository(
    runner: (input) async => computeDerivedMetricsFromBlobs(input),
  ).ensureCurrent('d');

  test('a switch logged on the surface stretches both reads alike', () async {
    await createDive(const [
      domain.DiveTank(
        id: 'back',
        volume: 12,
        startPressure: 200,
        endPressure: 110,
        role: TankRole.backGas,
      ),
      domain.DiveTank(
        id: 'o2',
        volume: 7,
        startPressure: 200,
        endPressure: 180,
        gasMix: domain.GasMix(o2: 100),
        role: TankRole.deco,
        order: 1,
      ),
    ]);
    await insertSwitch('back', 0);
    await insertSwitch('o2', 35 * 60);
    await sweep();

    final detail = (await repository.getDiveById('d'))!;
    final listed = (await repository.getAllDives()).single;

    const breathing = SurfaceBreathing(until: 40 * 60);
    expect(detail.surfaceBreathing, breathing);
    final stretched = gasUseWindowOf(
      profile,
      time: (p) => p.timestamp,
      depth: (p) => p.depth,
      surfaceBreathing: breathing,
    )!;
    expect(detail.gasUse, stretched.use);
    expect(listed.surfaceBreathing, breathing);
    expect(listed.storedGasUse, detail.gasUse);
    expect(listed.sac, closeTo(detail.sac!, 1e-9));
  });

  test('a cylinder falling on the surface agrees with its own row', () async {
    await createDive(const [
      domain.DiveTank(id: 't', startPressure: 200, endPressure: 100),
    ]);
    // Flat before the descent, 90 bar to the end of the ascent, then 10 more
    // on a five-minute surface swim, then flat.
    double bar(int t) {
      if (t <= 2 * 60) return 200;
      if (t <= 30 * 60) return 200 - (t - 2 * 60) * 90 / (28 * 60);
      if (t <= 35 * 60) return 110 - (t - 30 * 60) * 10 / (5 * 60);
      return 100;
    }

    await TankPressureSeriesRepository().insertSeries(
      diveId: 'd',
      tankId: 't',
      samples: [
        for (var t = 0; t <= 40 * 60; t += 10)
          TankPressureSample(timestamp: t, pressure: bar(t)),
      ],
    );
    await sweep();

    final detail = (await repository.getDiveById('d'))!;
    final row = const GasAnalysisService()
        .calculateCylinderSac(
          dive: detail,
          profile: detail.profile,
          tankPressures: await TankPressureRepository().getTankPressuresForDive(
            'd',
          ),
        )
        .single;

    expect(detail.surfaceBreathing?.until, 35 * 60);
    expect(row.usageDuration?.inSeconds, detail.gasUse!.seconds);
    expect(row.sacRate, closeTo(detail.sac!, 1e-9));
    final listed = (await repository.getAllDives()).single;
    expect(listed.sac, closeTo(detail.sac!, 1e-9));
  });
}
