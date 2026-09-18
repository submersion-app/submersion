import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_centers/domain/services/rental_memory_resolver.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';

void main() {
  final when = DateTime(2026, 3, 12, 9, 30);

  Dive dive({
    List<DiveWeight> weights = const [],
    List<DiveTank> tanks = const [],
    WeightingFeedback? feedback,
    double? feedbackKg,
  }) => Dive(
    id: 'd1',
    dateTime: when,
    weights: weights,
    tanks: tanks,
    weightingFeedback: feedback,
    weightingFeedbackKg: feedbackKg,
  );

  const belt = DiveWeight(
    id: 'w1',
    diveId: 'd1',
    weightType: WeightType.belt,
    amountKg: 6,
    notes: 'their belt',
  );
  const trim = DiveWeight(
    id: 'w2',
    diveId: 'd1',
    weightType: WeightType.trimWeights,
    amountKg: 2,
  );
  const al80 = DiveTank(
    id: 't1',
    name: 'Their AL80',
    volume: 11.1,
    workingPressure: 207,
    startPressure: 200,
    endPressure: 60,
    gasMix: GasMix(o2: 32),
    role: TankRole.backGas,
    material: TankMaterial.aluminum,
    order: 0,
    presetName: 'al80',
    computerId: 'comp',
    transmitterSerial: 'TX1',
    sourceTankIndex: 0,
    regulatorEquipmentId: 'reg',
    equipmentId: 'tank',
  );

  test('fromDive carries date, weights, feedback and tanks', () {
    final last = LastDiveAtCenter.fromDive(
      dive(
        weights: const [belt, trim],
        tanks: const [al80],
        feedback: WeightingFeedback.overweighted,
        feedbackKg: 1,
      ),
    );
    expect(last.diveId, 'd1');
    expect(last.dateTime, when);
    expect(last.weights, const [belt, trim]);
    expect(last.tanks, const [al80]);
    expect(last.weightingFeedback, WeightingFeedback.overweighted);
    expect(last.weightingFeedbackKg, 1);
    expect(last.totalLeadKg, 8);
  });

  test('a dive with no weights or tanks resolves with empty lists', () {
    final last = LastDiveAtCenter.fromDive(dive());
    expect(last.weights, isEmpty);
    expect(last.tanks, isEmpty);
    expect(last.totalLeadKg, 0);
    expect(last.weightingFeedback, isNull);
  });

  test('weightsForNewDive copies type, amount and notes under fresh ids', () {
    final last = LastDiveAtCenter.fromDive(dive(weights: const [belt, trim]));
    var n = 0;
    final copies = last.weightsForNewDive(
      diveId: 'new',
      newId: () => 'id${n++}',
    );
    expect(copies.map((w) => w.id), ['id0', 'id1']);
    expect(copies.map((w) => w.diveId), ['new', 'new']);
    expect(copies.first.weightType, WeightType.belt);
    expect(copies.first.amountKg, 6);
    expect(copies.first.notes, 'their belt');
    expect(copies.last.weightType, WeightType.trimWeights);
    // The source list is untouched.
    expect(last.weights.first.id, 'w1');
  });

  test('tanksForNewDive keeps the rig and takes default pressures', () {
    final last = LastDiveAtCenter.fromDive(dive(tanks: const [al80]));
    final copies = last.tanksForNewDive(
      newId: () => 'fresh',
      startPressure: 210,
      endPressure: 50,
    );
    final copy = copies.single;
    expect(copy.id, 'fresh');
    expect(copy.name, 'Their AL80');
    expect(copy.volume, 11.1);
    expect(copy.workingPressure, 207);
    expect(copy.presetName, 'al80');
    expect(copy.material, TankMaterial.aluminum);
    expect(copy.gasMix, const GasMix(o2: 32));
    expect(copy.role, TankRole.backGas);
    expect(copy.order, 0);
    expect(copy.startPressure, 210);
    expect(copy.endPressure, 50);
    // Device, transmitter and owned-gear links belong to the old dive.
    expect(copy.computerId, isNull);
    expect(copy.transmitterSerial, isNull);
    expect(copy.sourceTankIndex, isNull);
    expect(copy.regulatorEquipmentId, isNull);
    expect(copy.equipmentId, isNull);
  });

  test('two reads of the same dive are equal', () {
    expect(
      LastDiveAtCenter.fromDive(dive(weights: const [belt])),
      LastDiveAtCenter.fromDive(dive(weights: const [belt])),
    );
    expect(
      LastDiveAtCenter.fromDive(dive(weights: const [belt])) ==
          LastDiveAtCenter.fromDive(dive(weights: const [trim])),
      isFalse,
    );
  });
}
