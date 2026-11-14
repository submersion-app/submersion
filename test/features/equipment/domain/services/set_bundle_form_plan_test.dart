import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/equipment/domain/services/set_bundle_form_plan.dart';
import 'package:submersion/features/weight_presets/domain/entities/weight_preset.dart';

/// What picking a set does to the weights already on the dive form
/// (issue #4525).
void main() {
  const belt6 = <WeightEntryDraft>[
    (weightType: WeightType.belt, amountKg: 2.72, notes: '', label: ''),
  ];
  const belt8 = <WeightEntryDraft>[
    (weightType: WeightType.belt, amountKg: 3.63, notes: '', label: ''),
  ];
  List<DiveWeight> onDive(List<WeightEntryDraft> drafts) => [
    for (final (i, d) in drafts.indexed)
      DiveWeight(
        id: 'w$i',
        diveId: 'dive',
        weightType: d.weightType,
        amountKg: d.amountKg,
        notes: d.notes,
        label: d.label,
      ),
  ];

  SetWeightsStep plan({
    List<WeightEntryDraft> dive = const [],
    List<WeightEntryDraft> bundle = belt6,
    List<WeightEntryDraft>? absorbed,
    bool auto = false,
  }) => planSetWeights(
    onDive: onDive(dive),
    bundleWeights: bundle,
    absorbedWeights: absorbed,
    auto: auto,
  );

  test('a set with no weights leaves the form alone', () {
    expect(plan(bundle: const [], dive: belt8), SetWeightsStep.none);
    expect(plan(bundle: const []), SetWeightsStep.none);
  });

  test('an empty Weights section is filled', () {
    expect(plan(), SetWeightsStep.fill);
    expect(plan(auto: true), SetWeightsStep.fill);
  });

  test('a manual pick over existing weights asks', () {
    expect(plan(dive: belt8), SetWeightsStep.ask);
  });

  test('an automatic apply never touches existing weights', () {
    expect(plan(dive: belt8, auto: true), SetWeightsStep.leave);
  });

  test('weights still exactly what an absorbed set filled are replaced '
      'without asking', () {
    expect(plan(dive: belt8, absorbed: belt8), SetWeightsStep.replace);
    expect(
      plan(dive: belt8, absorbed: belt8, auto: true),
      SetWeightsStep.replace,
    );
  });

  test('weights edited since the absorbed set filled them ask', () {
    expect(plan(dive: belt6, absorbed: belt8), SetWeightsStep.ask);
  });

  test('an absorbed set that carried no weights does not excuse the '
      'question', () {
    expect(plan(dive: belt8, absorbed: const []), SetWeightsStep.ask);
  });
}
