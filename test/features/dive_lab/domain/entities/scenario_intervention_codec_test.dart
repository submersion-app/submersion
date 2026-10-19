import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_intervention.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_intervention_codec.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

void main() {
  const all = <ScenarioIntervention>[
    SwitchGasIntervention(tank: ExistingTankRef('t1')),
    SwitchGasIntervention(
      tank: HypotheticalTankRef(
        gasMix: GasMix(o2: 50),
        volumeLiters: 11.1,
        startPressureBar: 200,
      ),
    ),
    LoseTankIntervention(tankId: 't2'),
    ShiftAscentIntervention(deltaSeconds: -300),
    AscendNowIntervention(),
    ChangeGfIntervention(gfLow: 40, gfHigh: 85),
    ShareGasIntervention(buddyFactor: 2.0),
    ShareGasIntervention(),
    BailOutIntervention(),
    BailOutIntervention(tank: ExistingTankRef('bo')),
    AscentPolicyIntervention(
      ascentRate: 6,
      lastStopDepth: 6,
      extraLastStopSeconds: 120,
      gasSwitchStopSeconds: 60,
    ),
    AscentPolicyIntervention(),
  ];

  test('every kind round-trips', () {
    final json = encodeInterventions(all);
    expect(decodeInterventions(json), equals(all));
  });

  test('the envelope carries the format version and kind names', () {
    final map = jsonDecode(encodeInterventions(all)) as Map<String, Object?>;
    expect(map['formatVersion'], scenarioInterventionFormatVersion);
    final list = map['interventions'] as List;
    expect((list.first as Map)['kind'], 'switchGas');
    expect((list[4] as Map)['kind'], 'ascendNow');
  });

  test('empty list round-trips', () {
    expect(decodeInterventions(encodeInterventions(const [])), isEmpty);
  });

  test('a newer format version is rejected', () {
    final json = jsonEncode({'formatVersion': 99, 'interventions': []});
    expect(() => decodeInterventions(json), throwsFormatException);
  });

  test('an unknown kind is rejected', () {
    final json = jsonEncode({
      'formatVersion': 1,
      'interventions': [
        {'kind': 'teleport'},
      ],
    });
    expect(() => decodeInterventions(json), throwsFormatException);
  });

  test('malformed input is rejected', () {
    expect(() => decodeInterventions('not json'), throwsFormatException);
    expect(() => decodeInterventions('[]'), throwsFormatException);
    expect(
      () => decodeInterventions(jsonEncode({'formatVersion': 1})),
      throwsFormatException,
    );
  });
}
