import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_lab/domain/entities/dive_scenario.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_intervention.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_mode.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

DiveScenario _scenario(
  List<ScenarioIntervention> interventions, {
  ScenarioMode mode = ScenarioMode.replay,
}) => DiveScenario(
  id: 's1',
  diveId: 'd1',
  name: 'test',
  branchSeconds: 1200,
  mode: mode,
  interventions: interventions,
  createdAt: DateTime(2026, 8, 21),
  updatedAt: DateTime(2026, 8, 21),
);

void main() {
  group('ScenarioIntervention flags', () {
    test('path-changing kinds require re-plan', () {
      expect(
        const ShiftAscentIntervention(deltaSeconds: -300).requiresReplan,
        isTrue,
      );
      expect(const AscendNowIntervention().requiresReplan, isTrue);
      expect(
        const AscentPolicyIntervention(ascentRate: 6).requiresReplan,
        isTrue,
      );
      expect(
        const ChangeGfIntervention(gfLow: 40, gfHigh: 85).requiresReplan,
        isFalse,
      );
      expect(const LoseTankIntervention(tankId: 't').requiresReplan, isFalse);
    });

    test('aborting kinds imply ascend-now', () {
      expect(const ShareGasIntervention().impliesAscendNow, isTrue);
      expect(const BailOutIntervention().impliesAscendNow, isTrue);
      expect(const AscendNowIntervention().impliesAscendNow, isTrue);
      expect(
        const SwitchGasIntervention(
          tank: ExistingTankRef('t'),
        ).impliesAscendNow,
        isFalse,
      );
    });

    test('hypothetical tank ref has a stable derived id', () {
      const ref = HypotheticalTankRef(
        gasMix: GasMix(o2: 50),
        volumeLiters: 11.1,
        startPressureBar: 200,
      );
      expect(ref.tankId, 'lab-hypothetical-50-0-11-200');
      expect(
        ref.tankId,
        const HypotheticalTankRef(
          gasMix: GasMix(o2: 50),
          volumeLiters: 11.1,
          startPressureBar: 200,
        ).tankId,
      );
    });
  });

  group('DiveScenario', () {
    test('effectiveMode flips to re-plan when a path change is present', () {
      expect(_scenario(const []).effectiveMode, ScenarioMode.replay);
      expect(
        _scenario(const [AscendNowIntervention()]).effectiveMode,
        ScenarioMode.replan,
      );
      expect(
        _scenario(const [
          ChangeGfIntervention(gfLow: 40, gfHigh: 85),
        ], mode: ScenarioMode.replan).effectiveMode,
        ScenarioMode.replan,
      );
    });

    test('abortsAtBranch only in re-plan with an aborting intervention', () {
      expect(_scenario(const [ShareGasIntervention()]).abortsAtBranch, isFalse);
      expect(
        _scenario(const [
          ShareGasIntervention(),
        ], mode: ScenarioMode.replan).abortsAtBranch,
        isTrue,
      );
    });

    test('copyWith replaces interventions', () {
      final s = _scenario(const []);
      final c = s.copyWith(interventions: const [AscendNowIntervention()]);
      expect(c.interventions, hasLength(1));
      expect(s.interventions, isEmpty);
      expect(c.id, s.id);
    });
  });

  group('validateInterventions', () {
    test('duplicate kinds are rejected', () {
      final errors = validateInterventions(const [
        ChangeGfIntervention(gfLow: 30, gfHigh: 70),
        ChangeGfIntervention(gfLow: 40, gfHigh: 85),
      ]);
      expect(errors, contains(ScenarioValidationError.duplicateKind));
    });

    test('shiftAscent cannot combine with an aborting kind', () {
      final errors = validateInterventions(const [
        ShiftAscentIntervention(deltaSeconds: -60),
        ShareGasIntervention(),
      ]);
      expect(errors, contains(ScenarioValidationError.shiftAscentWithAbort));
    });

    test('a valid stack has no errors', () {
      expect(
        validateInterventions(const [
          LoseTankIntervention(tankId: 'deco'),
          ChangeGfIntervention(gfLow: 40, gfHigh: 85),
          AscendNowIntervention(),
        ]),
        isEmpty,
      );
    });
  });
}
