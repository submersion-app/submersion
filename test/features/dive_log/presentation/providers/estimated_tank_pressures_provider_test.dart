import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/data/services/estimated_tank_pressure_synthesizer.dart';
import 'package:submersion/features/dive_log/domain/entities/source_profile.dart';
import 'package:submersion/features/dive_log/presentation/providers/active_source_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/chart_tank_pressures_provider.dart';
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
        TankPressurePoint(tankId: 't1', timestamp: 0, pressure: 200),
        TankPressurePoint(tankId: 't1', timestamp: 1800, pressure: 60),
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

  test('builds on the active source\'s pressures, not the union', () async {
    // Two computers on one transmitter (#543's pressure twin): the union
    // interleaves both computers' readings on t1, the active-source read
    // keeps one. The chart draws this provider, so it must start from the
    // scoped map or the fuzzy union comes straight back.
    const scoped = <String, List<TankPressurePoint>>{
      't1': [
        TankPressurePoint(tankId: 't1', timestamp: 2, pressure: 225.5),
        TankPressurePoint(tankId: 't1', timestamp: 4, pressure: 225.0),
      ],
    };
    const union = <String, List<TankPressurePoint>>{
      't1': [
        TankPressurePoint(tankId: 't1', timestamp: 2, pressure: 225.5),
        TankPressurePoint(tankId: 't1', timestamp: 3, pressure: 223.5),
        TankPressurePoint(tankId: 't1', timestamp: 4, pressure: 225.0),
        TankPressurePoint(tankId: 't1', timestamp: 5, pressure: 223.3),
      ],
    };
    final dive = Dive(
      id: 'd1',
      dateTime: DateTime(2026, 5, 6),
      tanks: const [DiveTank(id: 't1', gasMix: GasMix(o2: 32))],
      profile: const [
        DiveProfilePoint(timestamp: 0, depth: 0),
        DiveProfilePoint(timestamp: 6, depth: 0),
      ],
    );

    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        tankPressuresProvider('d1').overrideWith((ref) async => union),
        activeSourceTankPressuresProvider(
          'd1',
        ).overrideWith((ref) async => scoped),
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
    expect(result.pressures['t1']!.map((p) => p.timestamp), [2, 4]);
  });

  test('passes the real map through when the dive no longer exists', () async {
    // A deleted dive mid-navigation: nothing to estimate against, so the
    // measured series (if any) are returned unchanged and nothing is marked
    // as an estimate.
    const real = <String, List<TankPressurePoint>>{
      't1': [TankPressurePoint(tankId: 't1', timestamp: 0, pressure: 200)],
    };
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        activeSourceTankPressuresProvider(
          'd1',
        ).overrideWith((ref) async => real),
        diveProvider('d1').overrideWith((ref) async => null),
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
    expect(result.pressures, same(real));
  });

  group('windows from the drawn computer\'s own switches (#4300)', () {
    GasSwitchWithTank change(String computer, int time, String tankId) =>
        GasSwitchWithTank(
          gasSwitch: GasSwitch(
            id: 'switch-$computer-$tankId',
            diveId: 'd1',
            timestamp: time,
            tankId: tankId,
            computerId: computer,
            createdAt: DateTime.utc(2026),
          ),
          tankName: tankId,
          gasMix: 'EAN50',
          o2Fraction: 0.5,
        );

    Future<EstimatedTankPressures> estimate({
      required Dive dive,
      required List<GasSwitchWithTank> switches,
      SourceProfile? active,
    }) async {
      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          activeSourceTankPressuresProvider(
            'd1',
          ).overrideWith((ref) async => <String, List<TankPressurePoint>>{}),
          activeSourceProfileProvider('d1').overrideWith((ref) => active),
          diveProvider('d1').overrideWith((ref) async => dive),
          gasSwitchesProvider('d1').overrideWith((ref) async => switches),
        ],
      );
      addTearDown(container.dispose);
      return container.read(estimatedTankPressuresProvider('d1').future);
    }

    /// The last moment [points] still reads [start]: where the drop begins.
    int dropStart(List<TankPressurePoint> points, double start) => points
        .where((p) => p.pressure == start)
        .map((p) => p.timestamp)
        .reduce((a, b) => a > b ? a : b);

    test(
      'another computer\'s earlier switch does not start the drop',
      () async {
        const profile = [
          DiveProfilePoint(timestamp: 0, depth: 0),
          DiveProfilePoint(timestamp: 1200, depth: 0),
        ];
        final dive = Dive(
          id: 'd1',
          dateTime: DateTime(2026, 1, 1),
          tanks: const [
            DiveTank(
              id: 'air',
              computerId: 'computer-a',
              sharedComputerIds: ['computer-b'],
              gasMix: GasMix(o2: 21),
              startPressure: 200,
              endPressure: 100,
            ),
            DiveTank(
              id: 'deco',
              computerId: 'computer-a',
              sharedComputerIds: ['computer-b'],
              gasMix: GasMix(o2: 50),
              role: TankRole.deco,
              order: 1,
              startPressure: 200,
              endPressure: 150,
            ),
          ],
          profile: profile,
        );

        final result = await estimate(
          dive: dive,
          switches: [
            change('computer-b', 600, 'deco'),
            change('computer-a', 900, 'deco'),
          ],
          active: const SourceProfile(
            sourceId: 's-a',
            computerId: 'computer-a',
            isEdited: false,
            points: profile,
          ),
        );

        expect(dropStart(result.pressures['deco']!, 200), 900);
      },
    );

    test(
      'an open-circuit dive starts on the back gas, not the diluent',
      () async {
        // Off the loop a diluent tag does not take the start, as on the chart's
        // gas strip, so the back gas is breathed until the switch at 600 s.
        final dive = Dive(
          id: 'd1',
          dateTime: DateTime(2026, 1, 1),
          diveMode: DiveMode.oc,
          tanks: const [
            DiveTank(
              id: 'dil',
              gasMix: GasMix(o2: 10, he: 50),
              role: TankRole.diluent,
              startPressure: 200,
              endPressure: 180,
            ),
            DiveTank(
              id: 'back',
              gasMix: GasMix(o2: 21),
              order: 1,
              startPressure: 200,
              endPressure: 120,
            ),
            DiveTank(
              id: 'deco',
              gasMix: GasMix(o2: 50),
              role: TankRole.deco,
              order: 2,
              startPressure: 200,
              endPressure: 150,
            ),
          ],
          profile: const [
            DiveProfilePoint(timestamp: 0, depth: 0),
            DiveProfilePoint(timestamp: 1200, depth: 0),
          ],
        );

        final result = await estimate(
          dive: dive,
          switches: [change('computer-a', 600, 'deco')],
        );

        final back = result.pressures['back']!;
        expect(
          back.firstWhere((p) => p.pressure == 120).timestamp,
          600,
          reason: 'the back gas is breathed from the start until the switch',
        );
      },
    );
  });
}
