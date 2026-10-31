import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_settings.dart';
import 'package:submersion/features/dive_lab/domain/services/scenario_engine.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_draft_provider.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_request_inputs_provider.dart';
import 'package:submersion/features/dive_lab/presentation/providers/scenario_outcome_provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

import '../../domain/support/synthetic_dives.dart';

LabRequestInputs _inputs() {
  final d = squareDive();
  return LabRequestInputs(
    dive: Dive(id: 'd', diveNumber: 1, dateTime: DateTime(2026)),
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
  late ProviderContainer c;
  late int runs;

  setUp(() {
    runs = 0;
    c = ProviderContainer(
      overrides: [
        labRequestInputsProvider('d').overrideWith((ref) async => _inputs()),
        scenarioEngineRunnerProvider.overrideWithValue((request) async {
          runs++;
          return const ScenarioEngine().run(request);
        }),
      ],
    );
    // The provider is autoDispose: the page keeps it alive by watching it.
    // Without a listener a bare read would dispose it mid-await and the
    // "superseded" guard would (correctly) never resolve.
    final sub = c.listen(scenarioOutcomeProvider('d'), (_, _) {});
    addTearDown(sub.close);
  });
  tearDown(() => c.dispose());

  test('unseeded draft yields null without running the engine', () async {
    expect(await c.read(scenarioOutcomeProvider('d').future), isNull);
    expect(runs, 0);
  });

  test('a seeded draft runs once and reports the branch', () async {
    c.read(labDraftProvider('d').notifier).seedBranch(900);
    final o = await c.read(scenarioOutcomeProvider('d').future);
    expect(o, isNotNull);
    expect(o!.branch.runtimeSeconds, 900);
    expect(runs, 1);
  });

  test('rapid edits collapse into one recompute', () async {
    c.read(labDraftProvider('d').notifier).seedBranch(900);
    await c.read(scenarioOutcomeProvider('d').future);
    expect(runs, 1);
    final n = c.read(labDraftProvider('d').notifier);
    n.nudgeBranch(10, maxSeconds: 3000);
    n.nudgeBranch(10, maxSeconds: 3000);
    n.nudgeBranch(10, maxSeconds: 3000);
    final o = await c.read(scenarioOutcomeProvider('d').future);
    expect(o!.branch.runtimeSeconds, 930);
    expect(runs, 2);
  });
}
