import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_intervention.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_mode.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_draft_provider.dart';

void main() {
  late ProviderContainer c;
  setUp(() => c = ProviderContainer());
  tearDown(() => c.dispose());

  LabDraftNotifier n() => c.read(labDraftProvider('d').notifier);
  LabDraft d() => c.read(labDraftProvider('d'));

  test('starts unseeded; seedBranch applies once', () {
    expect(d().isSeeded, isFalse);
    n().seedBranch(900);
    expect(d().branchSeconds, 900);
    n().seedBranch(100);
    expect(d().branchSeconds, 900);
  });

  test('set and nudge clamp to the dive duration', () {
    n().seedBranch(900);
    n().nudgeBranch(-60, maxSeconds: 1800);
    expect(d().branchSeconds, 840);
    n().nudgeBranch(5000, maxSeconds: 1800);
    expect(d().branchSeconds, 1800);
    n().setBranchSeconds(-5, maxSeconds: 1800);
    expect(d().branchSeconds, 0);
  });

  test('adding a path-changing intervention forces re-plan', () {
    n().setMode(ScenarioMode.replay);
    n().addIntervention(const AscendNowIntervention());
    expect(d().mode, ScenarioMode.replan);
    expect(d().modeForced, isTrue);
    n().setMode(ScenarioMode.replay); // ignored while forced
    expect(d().effectiveMode, ScenarioMode.replan);
    n().removeIntervention(InterventionKind.ascendNow);
    expect(d().modeForced, isFalse);
    n().setMode(ScenarioMode.replay);
    expect(d().mode, ScenarioMode.replay);
  });

  test('adding the same kind replaces it', () {
    n().addIntervention(const ChangeGfIntervention(gfLow: 30, gfHigh: 70));
    n().addIntervention(const ChangeGfIntervention(gfLow: 40, gfHigh: 85));
    expect(d().interventions, hasLength(1));
    expect((d().interventions.single as ChangeGfIntervention).gfHigh, 85);
    n().clearInterventions();
    expect(d().interventions, isEmpty);
  });

  test('toScenario carries the draft fields', () {
    n().seedBranch(600);
    n().addIntervention(const ShareGasIntervention());
    final s = d().toScenario('dive-1');
    expect(s.diveId, 'dive-1');
    expect(s.branchSeconds, 600);
    expect(s.interventions.single, const ShareGasIntervention());
    expect(s.effectiveMode, ScenarioMode.replay);
  });
}
