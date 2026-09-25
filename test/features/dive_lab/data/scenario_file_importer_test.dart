import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_lab/data/repositories/dive_scenario_repository.dart';
import 'package:submersion/features/dive_lab/data/services/scenario_file_codec.dart';
import 'package:submersion/features/dive_lab/data/services/scenario_file_importer.dart';
import 'package:submersion/features/dive_lab/domain/entities/dive_scenario.dart';
import 'package:submersion/features/dive_lab/domain/entities/dive_snapshot.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_intervention.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_mode.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_request.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

import '../../../helpers/test_database.dart';

SublabFile _file({String diveId = 'shared-dive'}) => SublabFile(
  scenario: DiveScenario(
    id: 'remote-sc',
    diveId: diveId,
    name: 'Lost 50%',
    branchSeconds: 1420,
    mode: ScenarioMode.replan,
    interventions: const [LoseTankIntervention(tankId: 'deco50')],
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  ),
  snapshot: DiveSnapshot(
    diveId: diveId,
    diveDateTime: DateTime(2026, 8, 1),
    waterType: WaterType.salt,
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
        id: 'deco50',
        volume: 11.1,
        startPressure: 200,
        gasMix: GasMix(o2: 50),
        role: TankRole.deco,
      ),
    ],
    gasSwitches: const [ScenarioGasSwitch(timestamp: 1600, tankId: 'deco50')],
    profile: [
      for (var t = 0; t <= 1800; t += 10)
        DiveProfilePoint(timestamp: t, depth: t < 1500 ? 40 : 5),
    ],
    tankPressures: const {
      'back': [
        TankPressureSample(timestamp: 0, pressureBar: 200),
        TankPressureSample(timestamp: 900, pressureBar: 140),
      ],
    },
  ),
);

void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  test('creates the dive from the snapshot when missing', () async {
    final result = await ScenarioFileImporter().import(
      _file(),
      diveNotes: 'Shared via a Dive Lab scenario file',
    );
    expect(result.diveCreated, isTrue);
    expect(result.alreadyPresent, isFalse);
    final dive = await DiveRepository().getDiveById(result.diveId);
    expect(dive, isNotNull);
    expect(dive!.tanks.map((t) => t.id), containsAll(['back', 'deco50']));
    expect(dive.notes, 'Shared via a Dive Lab scenario file');
    final profile = await DiveRepository().getDiveProfile(result.diveId);
    expect(profile.length, 181);
    final switches = await DiveRepository().getGasSwitchesForDive(
      result.diveId,
    );
    expect(switches.single.timestamp, 1600);
    final pressures = await TankPressureRepository().getTankPressuresForDive(
      result.diveId,
    );
    expect(pressures['back'], hasLength(2));
    final scenarios = await DiveScenarioRepository().getScenariosForDive(
      result.diveId,
    );
    expect(scenarios.single.name, 'Lost 50%');
    expect(scenarios.single.id, isNot('remote-sc'));
  });

  test(
    'attaches to an existing dive and dedupes identical re-imports',
    () async {
      final dive = await DiveRepository().createDive(
        Dive(id: 'shared-dive', diveNumber: 1, dateTime: DateTime(2026, 8, 1)),
      );
      final first = await ScenarioFileImporter().import(
        _file(diveId: dive.id),
        diveNotes: 'n/a',
      );
      expect(first.diveCreated, isFalse);
      expect(first.alreadyPresent, isFalse);
      final second = await ScenarioFileImporter().import(
        _file(diveId: dive.id),
        diveNotes: 'n/a',
      );
      expect(second.alreadyPresent, isTrue);
      expect(second.scenarioId, first.scenarioId);
      expect(
        await DiveScenarioRepository().getScenariosForDive(dive.id),
        hasLength(1),
      );
    },
  );
}
