import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  test('augments real map with an estimated line for a manual tank', () async {
    final dive = Dive(
      id: 'd1',
      dateTime: DateTime(2026, 1, 1),
      tanks: const [
        DiveTank(
          id: 't1',
          gasMix: GasMix(o2: 21),
          startPressure: 200,
          endPressure: 60,
        ),
      ],
      profile: const [
        DiveProfilePoint(timestamp: 0, depth: 0),
        DiveProfilePoint(timestamp: 1800, depth: 0),
      ],
    );

    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        tankPressuresProvider(
          'd1',
        ).overrideWith((ref) async => <String, List<TankPressurePoint>>{}),
        diveProvider('d1').overrideWith((ref) async => dive),
        gasSwitchesProvider(
          'd1',
        ).overrideWith((ref) async => <GasSwitchWithTank>[]),
      ],
    );
    addTearDown(container.dispose);

    final result = await container.read(
      estimatedTankPressuresProvider('d1').future,
    );

    expect(result.estimatedTankIds, {'t1'});
    expect(result.pressures['t1']!.first.pressure, 200);
    expect(result.pressures['t1']!.last.pressure, 60);
  });

  test('does not estimate pressures for a gauge dive', () async {
    // Issue #731: a gauge (bottom-timer) dive models no gas, so a synthesized
    // pressure trace would be fabricated data rather than a measurement.
    final dive = Dive(
      id: 'd1',
      dateTime: DateTime(2026, 1, 1),
      diveMode: DiveMode.gauge,
      tanks: const [
        DiveTank(
          id: 't1',
          gasMix: GasMix(o2: 21),
          startPressure: 200,
          endPressure: 60,
        ),
      ],
      profile: const [
        DiveProfilePoint(timestamp: 0, depth: 0),
        DiveProfilePoint(timestamp: 1800, depth: 0),
      ],
    );

    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        tankPressuresProvider(
          'd1',
        ).overrideWith((ref) async => <String, List<TankPressurePoint>>{}),
        diveProvider('d1').overrideWith((ref) async => dive),
        gasSwitchesProvider(
          'd1',
        ).overrideWith((ref) async => <GasSwitchWithTank>[]),
      ],
    );
    addTearDown(container.dispose);

    final result = await container.read(
      estimatedTankPressuresProvider('d1').future,
    );

    expect(result.estimatedTankIds, isEmpty);
    expect(result.pressures, isEmpty);
  });

  test('keeps real transmitter pressures on a gauge dive', () async {
    // Only the synthesized line is suppressed; measured air-integrated data
    // is real and still plots.
    const real = <String, List<TankPressurePoint>>{
      't1': [
        TankPressurePoint(id: 'p1', tankId: 't1', timestamp: 0, pressure: 200),
        TankPressurePoint(
          id: 'p2',
          tankId: 't1',
          timestamp: 1800,
          pressure: 60,
        ),
      ],
    };
    final dive = Dive(
      id: 'd1',
      dateTime: DateTime(2026, 1, 1),
      diveMode: DiveMode.gauge,
      tanks: const [
        DiveTank(
          id: 't1',
          gasMix: GasMix(o2: 21),
          startPressure: 200,
          endPressure: 60,
        ),
      ],
      profile: const [
        DiveProfilePoint(timestamp: 0, depth: 0),
        DiveProfilePoint(timestamp: 1800, depth: 0),
      ],
    );

    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        tankPressuresProvider('d1').overrideWith((ref) async => real),
        diveProvider('d1').overrideWith((ref) async => dive),
        gasSwitchesProvider(
          'd1',
        ).overrideWith((ref) async => <GasSwitchWithTank>[]),
      ],
    );
    addTearDown(container.dispose);

    final result = await container.read(
      estimatedTankPressuresProvider('d1').future,
    );

    expect(result.estimatedTankIds, isEmpty);
    expect(result.pressures['t1'], hasLength(2));
  });

  test(
    'does not estimate pressures when the diver turned estimates off',
    () async {
      // Issue #731: the estimated line had no off switch. With the preference
      // off the series is never synthesized, so no legend chip, tooltip row, or
      // "(est.)" label appears anywhere.
      final dive = Dive(
        id: 'd1',
        dateTime: DateTime(2026, 1, 1),
        tanks: const [
          DiveTank(
            id: 't1',
            gasMix: GasMix(o2: 21),
            startPressure: 200,
            endPressure: 60,
          ),
        ],
        profile: const [
          DiveProfilePoint(timestamp: 0, depth: 0),
          DiveProfilePoint(timestamp: 1800, depth: 0),
        ],
      );

      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith(
            (ref) => MockSettingsNotifier(
              const AppSettings(defaultShowEstimatedTankPressure: false),
            ),
          ),
          tankPressuresProvider(
            'd1',
          ).overrideWith((ref) async => <String, List<TankPressurePoint>>{}),
          diveProvider('d1').overrideWith((ref) async => dive),
          gasSwitchesProvider(
            'd1',
          ).overrideWith((ref) async => <GasSwitchWithTank>[]),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        estimatedTankPressuresProvider('d1').future,
      );

      expect(result.estimatedTankIds, isEmpty);
      expect(result.pressures, isEmpty);
    },
  );

  test('estimates pressures when the preference is left on', () async {
    final dive = Dive(
      id: 'd1',
      dateTime: DateTime(2026, 1, 1),
      tanks: const [
        DiveTank(
          id: 't1',
          gasMix: GasMix(o2: 21),
          startPressure: 200,
          endPressure: 60,
        ),
      ],
      profile: const [
        DiveProfilePoint(timestamp: 0, depth: 0),
        DiveProfilePoint(timestamp: 1800, depth: 0),
      ],
    );

    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith(
          (ref) => MockSettingsNotifier(
            const AppSettings(defaultShowEstimatedTankPressure: true),
          ),
        ),
        tankPressuresProvider(
          'd1',
        ).overrideWith((ref) async => <String, List<TankPressurePoint>>{}),
        diveProvider('d1').overrideWith((ref) async => dive),
        gasSwitchesProvider(
          'd1',
        ).overrideWith((ref) async => <GasSwitchWithTank>[]),
      ],
    );
    addTearDown(container.dispose);

    final result = await container.read(
      estimatedTankPressuresProvider('d1').future,
    );

    expect(result.estimatedTankIds, {'t1'});
  });

  test('estimates pressures by default', () async {
    expect(const AppSettings().defaultShowEstimatedTankPressure, isTrue);
  });
}
