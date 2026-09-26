import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_request_inputs_provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

List<DiveProfilePoint> _square() => [
  for (var t = 0; t <= 1800; t += 10)
    DiveProfilePoint(
      timestamp: t,
      depth: t < 120
          ? t / 3.0
          : (t < 1500 ? 40.0 : 40.0 - (t - 1500) / 300 * 40.0),
    ),
];

void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  ProviderContainer container() => ProviderContainer(
    overrides: [
      settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      loggedAverageSacProvider.overrideWith((ref) async => 17.0),
    ],
  );

  test('assembles the request inputs from the real database', () async {
    final dive = await DiveRepository().createDive(
      Dive(
        id: '',
        diveNumber: 1,
        dateTime: DateTime(2026, 1, 1),
        profile: _square(),
        gradientFactorLow: 35,
        gradientFactorHigh: 75,
        tanks: const [
          DiveTank(
            id: 'back',
            volume: 24,
            startPressure: 200,
            endPressure: 80,
            gasMix: GasMix(o2: 21),
            role: TankRole.backGas,
          ),
          DiveTank(
            id: 'deco',
            volume: 11.1,
            startPressure: 200,
            endPressure: 150,
            gasMix: GasMix(o2: 50),
            role: TankRole.deco,
          ),
        ],
      ),
    );
    await DiveRepository().createGasSwitch(
      GasSwitch(
        id: 'sw1',
        diveId: dive.id,
        timestamp: 1600,
        tankId: 'deco',
        depth: 21,
        createdAt: DateTime(2026),
      ),
    );
    await TankPressureRepository().insertTankPressures(dive.id, {
      'back': [
        (timestamp: 0, pressure: 200.0),
        (timestamp: 900, pressure: 140.0),
      ],
    });

    final c = container();
    addTearDown(c.dispose);
    final inputs = await c.read(labRequestInputsProvider(dive.id).future);
    expect(inputs, isNotNull);
    expect(inputs!.depths.length, _square().length);
    expect(inputs.timestamps.last, 1800);
    expect(inputs.tanks.map((t) => t.id), containsAll(['back', 'deco']));
    expect(inputs.gasSwitches.single.timestamp, 1600);
    expect(inputs.gasSwitches.single.tankId, 'deco');
    expect(inputs.tankPressures['back']!.last.pressureBar, 140.0);
    expect(inputs.settings.gfLowPercent, 35);
    expect(inputs.settings.gfHighPercent, 75);
    expect(inputs.fallbackSacLpm, 17.0);
    expect(inputs.diveMode, DiveMode.oc);
    expect(inputs.loopGasSegments, isNull);
    expect(inputs.durationSeconds, 1800);
  });

  test('a gauge dive is ineligible', () async {
    final dive = await DiveRepository().createDive(
      Dive(
        id: '',
        diveNumber: 2,
        dateTime: DateTime(2026, 1, 2),
        profile: _square(),
        diveMode: DiveMode.gauge,
      ),
    );
    final c = container();
    addTearDown(c.dispose);
    expect(await c.read(labRequestInputsProvider(dive.id).future), isNull);
  });
}
