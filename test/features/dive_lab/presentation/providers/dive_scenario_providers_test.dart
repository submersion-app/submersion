import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_lab/domain/entities/dive_scenario.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_mode.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_settings.dart';
import 'package:submersion/features/dive_lab/domain/services/scenario_engine.dart';
import 'package:submersion/features/dive_lab/presentation/providers/dive_scenario_providers.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_request_inputs_provider.dart';
import 'package:submersion/features/dive_lab/presentation/providers/scenario_outcome_provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

import '../../../../helpers/test_database.dart';
import '../../domain/support/synthetic_dives.dart';

LabRequestInputs _inputs(Dive dive) {
  final d = squareDive();
  return LabRequestInputs(
    dive: dive,
    profile: [
      for (var i = 0; i < d.depths.length; i++)
        DiveProfilePoint(timestamp: d.timestamps[i], depth: d.depths[i]),
    ],
    depths: d.depths,
    timestamps: d.timestamps,
    diveMode: DiveMode.oc,
    tanks: d.tanks,
    gasSwitches: d.switches,
    tankPressures: d.tankPressures,
    startCns: 0,
    startOtu: 0,
    settings: const ScenarioSettings(),
  );
}

void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  test(
    'list provider reflects saves; outcome provider runs a saved scenario',
    () async {
      final dive = await DiveRepository().createDive(
        Dive(id: '', diveNumber: 1, dateTime: DateTime(2026, 1, 1)),
      );
      final c = ProviderContainer(
        overrides: [
          labRequestInputsProvider(
            dive.id,
          ).overrideWith((ref) async => _inputs(dive)),
          scenarioEngineRunnerProvider.overrideWithValue(
            (request) async => const ScenarioEngine().run(request),
          ),
        ],
      );
      addTearDown(c.dispose);
      final sub = c.listen(diveScenariosForDiveProvider(dive.id), (_, _) {});
      addTearDown(sub.close);
      expect(
        await c.read(diveScenariosForDiveProvider(dive.id).future),
        isEmpty,
      );

      final saved = await c
          .read(diveScenarioRepositoryProvider)
          .saveScenario(
            DiveScenario(
              id: '',
              diveId: dive.id,
              name: 'n',
              branchSeconds: 600,
              mode: ScenarioMode.replay,
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
            ),
          );
      // The watch stream invalidates the list.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        (await c.read(diveScenariosForDiveProvider(dive.id).future)).single.id,
        saved.id,
      );
      final sub2 = c.listen(
        savedScenarioOutcomeProvider((diveId: dive.id, scenarioId: saved.id)),
        (_, _) {},
      );
      addTearDown(sub2.close);
      final outcome = await c.read(
        savedScenarioOutcomeProvider((
          diveId: dive.id,
          scenarioId: saved.id,
        )).future,
      );
      expect(outcome!.branch.runtimeSeconds, 600);
    },
  );
}
