import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/gas_consumption_display.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/insights/presentation/providers/insights_gas_lane_provider.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Issue #1873: average SAC and bottom time per water-temperature band,
/// following the gas page's lane and the diver's temperature unit.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  final now = DateTime(2026, 6, 1).millisecondsSinceEpoch;

  /// A 50 min dive at an average of 10 m (2 bar ambient) breathing 100 bar
  /// from a 12 L cylinder: SAC 1.0 bar/min.
  Future<void> dive(
    String id, {
    required double waterTemp,
    int bottomTimeSec = 3000,
    String diveMode = 'oc',
  }) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(now),
            waterTemp: Value(waterTemp),
            bottomTime: Value(bottomTimeSec),
            runtime: const Value(3000),
            avgDepth: const Value(10.0),
            diveMode: Value(diveMode),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion(
            id: Value('tank-$id'),
            diveId: Value(id),
            startPressure: const Value(200.0),
            endPressure: const Value(100.0),
            volume: const Value(12.0),
            o2Percent: const Value(21.0),
            hePercent: const Value(0.0),
            tankOrder: const Value(0),
          ),
        );
  }

  Future<ProviderContainer> container({MockSettingsNotifier? settings}) async {
    final c = ProviderContainer(
      overrides: (await getBaseOverrides(
        settingsNotifier: settings ?? MockSettingsNotifier(),
      )).cast(),
    );
    addTearDown(c.dispose);
    // Keep the provider subscribed so a dependency change invalidates it.
    c.listen(waterTempBandMetricsProvider, (_, _) {});
    return c;
  }

  test(
    'averages SAC in the gas scope and bottom time in the normal one',
    () async {
      await dive('oc', waterTemp: 5.0);
      // A gauge dive has no SAC in the gas statistics, but it is still a dive
      // in the band and still has a bottom time.
      await dive(
        'gauge',
        waterTemp: 5.0,
        bottomTimeSec: 2400,
        diveMode: 'gauge',
      );

      final c = await container();
      final bands = await c.read(waterTempBandMetricsProvider.future);

      final cold = bands.first;
      expect(cold.diveCount, 2);
      expect(cold.avgSac, closeTo(1.0, 1e-9));
      expect(cold.sacDiveCount, 1);
      expect(cold.avgBottomMinutes, closeTo(45.0, 1e-9));
      expect(cold.bottomTimeDiveCount, 2);
    },
  );

  test('follows the gas page lane: RMV reads the volume per dive', () async {
    await dive('a', waterTemp: 5.0);

    final c = await container(
      settings: MockSettingsNotifier(
        const AppSettings(gasConsumptionDisplay: GasConsumptionDisplay.both),
      ),
    );
    final sac = await c.read(waterTempBandMetricsProvider.future);
    expect(sac.first.avgSac, closeTo(1.0, 1e-9));

    c.read(insightsGasLaneOverrideProvider.notifier).state =
        GasConsumptionLane.rmv;

    final rmv = await c.read(waterTempBandMetricsProvider.future);
    final expected = await c
        .read(insightsRepositoryProvider)
        .getSacVolumePerDive();
    expect(rmv.first.avgSac, expected.single.value);
    expect(rmv.first.avgSac, isNot(closeTo(1.0, 1e-9)));
  });

  test('re-bins in the diver unit when the unit setting changes', () async {
    // 18.0 C is 64.4 F: 18-24 in Celsius, 50-65 in Fahrenheit.
    await dive('a', waterTemp: 18.0);

    final settings = MockSettingsNotifier();
    final c = await container(settings: settings);

    final celsius = await c.read(waterTempBandMetricsProvider.future);
    expect(celsius.map((b) => b.upper), [10, 18, 24, null]);
    expect(celsius.map((b) => b.sacDiveCount), [0, 0, 1, 0]);

    await settings.setTemperatureUnit(TemperatureUnit.fahrenheit);

    final fahrenheit = await c.read(waterTempBandMetricsProvider.future);
    expect(fahrenheit.map((b) => b.upper), [50, 65, 75, null]);
    expect(fahrenheit.map((b) => b.sacDiveCount), [0, 1, 0, 0]);
  });
}
