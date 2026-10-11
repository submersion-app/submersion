import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/utils/gas_compressibility.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late InsightsRepository repository;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = InsightsRepository();
  });
  tearDown(() async => tearDownTestDatabase());

  Future<void> dive(
    String id, {
    int day = 1,
    double? avgDepth,
    int? surfaceIntervalSeconds,
    double? airTemp,
    double? visibilityMeters,
    double? altitude,
    double? cnsEnd,
    double? otu,
    bool excluded = false,
    bool planned = false,
    bool excludedFromGas = false,
    String? diveMode,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(
              DateTime.utc(2025, 3, day, 9).millisecondsSinceEpoch,
            ),
            avgDepth: Value(avgDepth),
            surfaceIntervalSeconds: Value(surfaceIntervalSeconds),
            airTemp: Value(airTemp),
            visibilityMeters: Value(visibilityMeters),
            altitude: Value(altitude),
            cnsEnd: Value(cnsEnd),
            otu: Value(otu),
            excludedFromStats: Value(excluded),
            excludedFromGasStats: Value(excludedFromGas),
            diveMode: diveMode == null ? const Value.absent() : Value(diveMode),
            isPlanned: Value(planned),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> tank(
    String diveId,
    int order, {
    double volume = 12,
    double start = 200,
    double end = 100,
  }) => db
      .into(db.diveTanks)
      .insert(
        DiveTanksCompanion(
          id: Value('t-$diveId-$order'),
          diveId: Value(diveId),
          volume: Value(volume),
          startPressure: Value(start),
          endPressure: Value(end),
          o2Percent: const Value(21.0),
          hePercent: const Value(0.0),
          tankOrder: Value(order),
          tankRole: const Value('backGas'),
        ),
      );

  test(
    'each column series returns dives that have the value, by date',
    () async {
      await dive(
        'b',
        day: 2,
        avgDepth: 14,
        surfaceIntervalSeconds: 5400,
        airTemp: 22,
        visibilityMeters: 15,
        altitude: 300,
        cnsEnd: 12,
        otu: 30,
      );
      await dive(
        'a',
        day: 1,
        avgDepth: 10,
        surfaceIntervalSeconds: 600,
        airTemp: 18,
        visibilityMeters: 5,
        altitude: 0,
        cnsEnd: 8,
        otu: 20,
      );
      await dive('none', day: 3);

      final cases = <String, Future<List<TrendDataPoint>>>{
        'avgDepth': repository.getAvgDepthPerDive(),
        'surfaceInterval': repository.getSurfaceIntervalPerDive(),
        'airTemp': repository.getAirTempPerDive(),
        'visibility': repository.getVisibilityPerDive(),
        'altitude': repository.getAltitudePerDive(),
        'cns': repository.getCnsPerDive(),
        'otu': repository.getOtuPerDive(),
      };
      for (final entry in cases.entries) {
        final points = await entry.value;
        expect(points.map((p) => p.diveId), ['a', 'b'], reason: entry.key);
      }
      expect(
        (await repository.getSurfaceIntervalPerDive()).map((p) => p.value),
        [10, 90],
      );
      expect((await repository.getAltitudePerDive()).map((p) => p.value), [
        0,
        300,
      ]);
    },
  );

  test(
    'gas used sums every tank with the gas model the RMV series uses',
    () async {
      await dive('twin');
      await tank('twin', 0, volume: 12, start: 200, end: 100);
      await tank('twin', 1, volume: 12, start: 200, end: 150);
      await dive('empty');
      await tank('empty', 0, start: 100, end: 100);

      final points = await repository.getGasUsedPerDive();

      // Real gas, as the repository defaults to: a 12 L cylinder from 200 bar
      // holds less than the ideal 2400 L, so the sum is below 1800 L.
      double litres(double bar) => gasVolume(
        tankSizeLiters: 12,
        pressureBar: bar,
        o2Percent: 21,
        hePercent: 0,
        model: GasModel.real,
      );
      final expected =
          (litres(200) - litres(100)) + (litres(200) - litres(150));
      expect(expected, lessThan(1800));
      expect(points.single.diveId, 'twin');
      expect(points.single.value, closeTo(expected, 0.01));
    },
  );

  test('gas used follows the gas-statistics scope like RMV', () async {
    await dive('purge', excludedFromGas: true);
    await tank('purge', 0);
    await dive('gauge', diveMode: 'gauge');
    await tank('gauge', 0);
    await dive('in');
    await tank('in', 0);

    final points = await repository.getGasUsedPerDive();

    expect(points.map((p) => p.diveId), ['in']);
  });

  test('excluded and planned dives are out of every series', () async {
    await dive('x', avgDepth: 10, cnsEnd: 5, excluded: true);
    await dive('p', avgDepth: 10, cnsEnd: 5, planned: true);
    await tank('x', 0);
    await tank('p', 0);

    expect(await repository.getAvgDepthPerDive(), isEmpty);
    expect(await repository.getCnsPerDive(), isEmpty);
    expect(await repository.getGasUsedPerDive(), isEmpty);
  });
}
