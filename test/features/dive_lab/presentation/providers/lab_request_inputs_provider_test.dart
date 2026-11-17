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

  test(
    'carries the diver SCR defaults for a dive without its own (#4660)',
    () async {
      final dive = await DiveRepository().createDive(
        Dive(
          id: '',
          diveNumber: 1,
          dateTime: DateTime(2026, 1, 1),
          profile: _square(),
          tanks: const [
            DiveTank(
              id: 'back',
              volume: 12,
              startPressure: 200,
              endPressure: 100,
              gasMix: GasMix(o2: 21),
              role: TankRole.backGas,
            ),
          ],
        ),
      );
      final c = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith(
            (ref) => MockSettingsNotifier(
              const AppSettings(
                plannerScrInjectionRate: 7.5,
                plannerScrVo2: 2.0,
              ),
            ),
          ),
          loggedAverageSacProvider.overrideWith((ref) async => 17.0),
        ],
      );
      addTearDown(c.dispose);
      final inputs = await c.read(labRequestInputsProvider(dive.id).future);
      expect(inputs!.settings.defaultScrInjectionRateLpm, 7.5);
      expect(inputs.settings.defaultScrVo2Lpm, 2.0);
    },
  );

  Future<LabRequestInputs> scrInputs(ScrType? scrType, double? vo2) async {
    final dive = await DiveRepository().createDive(
      Dive(
        id: '',
        diveNumber: 1,
        dateTime: DateTime(2026, 1, 1),
        profile: _square(),
        diveMode: DiveMode.scr,
        scrType: scrType,
        assumedVo2: vo2,
        tanks: const [
          DiveTank(
            id: 'supply',
            volume: 7,
            startPressure: 200,
            endPressure: 100,
            gasMix: GasMix(o2: 50),
            role: TankRole.diluent,
          ),
        ],
      ),
    );
    final c = container();
    addTearDown(c.dispose);
    final inputs = await c.read(labRequestInputsProvider(dive.id).future);
    return inputs!;
  }

  test('a CMF dive re-plans at the VO2 it logged (#4660)', () async {
    final inputs = await scrInputs(ScrType.cmf, 1.5);
    expect(inputs.scrVo2, 1.5);
    expect(inputs.replanScrVo2, 1.5);
  });

  test('a dive with no VO2 re-plans at the diver default (#4660)', () async {
    final inputs = await scrInputs(ScrType.cmf, null);
    expect(inputs.replanScrVo2, isNull);
  });

  test('a passive SCR dive VO2 is not a CMF re-plan VO2 (#4660)', () async {
    final inputs = await scrInputs(ScrType.pascr, 0.72);
    // Analysed exactly as dive detail analyses it...
    expect(inputs.scrVo2, 0.72);
    // ...but the CMF re-plan falls back to the diver's SCR VO2.
    expect(inputs.replanScrVo2, isNull);
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

  test('a suit inflation bottle never reaches the lab (#4243)', () async {
    final dive = await DiveRepository().createDive(
      Dive(
        id: '',
        diveNumber: 1,
        dateTime: DateTime(2026, 1, 1),
        profile: _square(),
        tanks: const [
          DiveTank(
            id: 'suit',
            volume: 0.85,
            startPressure: 200,
            endPressure: 150,
            gasMix: GasMix(o2: 21),
            role: TankRole.suitInflation,
          ),
          DiveTank(
            id: 'back',
            volume: 24,
            startPressure: 200,
            endPressure: 80,
            gasMix: GasMix(o2: 21),
            role: TankRole.backGas,
          ),
        ],
      ),
    );
    await DiveRepository().createGasSwitch(
      GasSwitch(
        id: 'sw1',
        diveId: dive.id,
        timestamp: 1600,
        tankId: 'suit',
        createdAt: DateTime(2026),
      ),
    );
    await TankPressureRepository().insertTankPressures(dive.id, {
      'suit': [
        (timestamp: 0, pressure: 200.0),
        (timestamp: 1800, pressure: 150.0),
      ],
      'back': [
        (timestamp: 0, pressure: 200.0),
        (timestamp: 1800, pressure: 80.0),
      ],
    });

    final c = container();
    addTearDown(c.dispose);
    final inputs = await c.read(labRequestInputsProvider(dive.id).future);

    expect(inputs!.tanks.map((t) => t.id), ['back']);
    expect(inputs.gasSwitches.single.tankId, 'back');
    expect(inputs.tankPressures.keys, ['back']);
  });
}
