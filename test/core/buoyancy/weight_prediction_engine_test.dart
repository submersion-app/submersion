import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/buoyancy/gear_buoyancy_traits.dart';
import 'package:submersion/core/buoyancy/gear_feature.dart';
import 'package:submersion/core/buoyancy/weight_observation.dart';
import 'package:submersion/core/buoyancy/weight_prediction_engine.dart';
import 'package:submersion/core/constants/enums.dart';

void main() {
  final now = DateTime(2026, 7, 1);

  const suit = GearFeature(
    id: 'suit',
    label: '5mm Suit',
    priorKg: 5.0,
    priorStrength: 2.0,
    dryMassKg: 2.0,
  );
  const bcd = GearFeature(
    id: 'bcd',
    label: 'BCD',
    priorKg: -0.5,
    priorStrength: 2.0,
    dryMassKg: 3.5,
  );
  const drysuit = GearFeature(
    id: 'drysuit',
    label: 'Drysuit',
    priorKg: 10.0,
    priorStrength: 2.0,
    dryMassKg: 3.0,
  );

  const al80 = ObservedTank(
    presetName: 'al80',
    volumeL: 11.1,
    workingPressureBar: 207,
    material: TankMaterial.aluminum,
  );
  const al80Spec = TankSpec(
    presetName: 'al80',
    volumeL: 11.1,
    workingPressureBar: 207,
    material: TankMaterial.aluminum,
  );

  GearFeature? gearById(String id) => switch (id) {
    'suit' => suit,
    'bcd' => bcd,
    'drysuit' => drysuit,
    _ => null,
  };

  WeightObservation obs({
    required int index,
    double carriedKg = 8.0,
    String? feedback = 'correct',
    double? feedbackKg,
    WaterType waterType = WaterType.salt,
  }) => WeightObservation(
    diveId: 'd$index',
    diveDateTime: now.subtract(Duration(days: index)),
    waterType: waterType,
    carriedKg: carriedKg,
    equipmentIds: const ['suit', 'bcd'],
    tanks: const [al80],
    feedback: feedback,
    feedbackKg: feedbackKg,
  );

  RigSpec rig({List<GearFeature>? gear, WaterType? waterType}) => RigSpec(
    gear: gear ?? const [suit, bcd],
    tanks: const [al80Spec],
    waterType: waterType ?? WaterType.salt,
    bodyWeightKg: 80,
  );

  FittedWeightModel fit(
    List<WeightObservation> observations, {
    double? bodyWeightKg = 80,
  }) => WeightPredictionEngine.fit(
    observations: observations,
    gearById: gearById,
    bodyWeightKg: bodyWeightKg,
    now: now,
  );

  test('zero history predicts from priors + physics, low confidence', () {
    final model = fit(const []);
    final prediction = model.predict(rig());
    expect(prediction.confidence, PredictionConfidence.low);
    expect(prediction.supportingDives, 0);
    expect(prediction.totalKg, greaterThanOrEqualTo(0));
    // personal prior 3.0 + suit 5.0 + bcd -0.5 + al80 ~1.02 + water 0
    expect(prediction.totalKg, closeTo(8.52, 0.1));
  });

  test('20 consistent salt dives predict the carried weight, high '
      'confidence', () {
    final model = fit([for (var i = 0; i < 20; i++) obs(index: i)]);
    final prediction = model.predict(rig());
    expect(prediction.totalKg, closeTo(8.0, 0.5));
    expect(prediction.confidence, PredictionConfidence.high);
    expect(prediction.supportingDives, 20);
  });

  test('fresh water prediction drops by the displaced-mass water term', () {
    final model = fit([for (var i = 0; i < 20; i++) obs(index: i)]);
    final salt = model.predict(rig()).totalKg;
    final fresh = model.predict(rig(waterType: WaterType.fresh)).totalKg;
    expect(salt - fresh, greaterThan(1.5));
    expect(salt - fresh, lessThan(3.5));
  });

  test('unseen drysuit swap increases the prediction by roughly the prior '
      'difference', () {
    final model = fit([for (var i = 0; i < 20; i++) obs(index: i)]);
    final wet = model.predict(rig()).totalKg;
    final dry = model.predict(rig(gear: const [drysuit, bcd])).totalKg;
    expect(dry - wet, greaterThan(3.0));
    expect(dry - wet, lessThan(7.0));
  });

  test('chronic overweighting with feedback predicts the corrected weight', () {
    final model = fit([
      for (var i = 0; i < 15; i++)
        obs(
          index: i,
          carriedKg: 10.0,
          feedback: 'overweighted',
          feedbackKg: 2.0,
        ),
    ]);
    final prediction = model.predict(rig());
    expect(prediction.totalKg, greaterThan(7.5));
    expect(prediction.totalKg, lessThan(8.5));
  });

  test('feedback without magnitude applies the 1 kg default', () {
    final withMagnitude = fit([
      for (var i = 0; i < 10; i++)
        obs(
          index: i,
          carriedKg: 10.0,
          feedback: 'overweighted',
          feedbackKg: 1.0,
        ),
    ]).predict(rig()).totalKg;
    final withoutMagnitude = fit([
      for (var i = 0; i < 10; i++)
        obs(index: i, carriedKg: 10.0, feedback: 'overweighted'),
    ]).predict(rig()).totalKg;
    expect(withoutMagnitude, closeTo(withMagnitude, 0.01));
  });

  test('a single wild outlier barely moves the prediction', () {
    final clean = [for (var i = 0; i < 10; i++) obs(index: i)];
    final withOutlier = [
      ...clean,
      obs(index: 10, carriedKg: 25.0, feedback: null),
    ];
    final cleanTotal = fit(clean).predict(rig()).totalKg;
    final outlierTotal = fit(withOutlier).predict(rig()).totalKg;
    expect((outlierTotal - cleanTotal).abs(), lessThan(0.7));
  });

  test('missing body weight caps confidence below high', () {
    final model = fit([
      for (var i = 0; i < 20; i++) obs(index: i),
    ], bodyWeightKg: null);
    final prediction = model.predict(
      const RigSpec(
        gear: [suit, bcd],
        tanks: [al80Spec],
        waterType: WaterType.salt,
      ),
    );
    expect(prediction.confidence, isNot(PredictionConfidence.high));
  });

  test('prediction clamps at zero', () {
    const sinker = GearFeature(
      id: 'anchor',
      label: 'Anchor',
      priorKg: -50.0,
      priorStrength: 8.0,
      dryMassKg: 20.0,
      hasUserSpec: true,
    );
    final prediction = fit(const []).predict(
      const RigSpec(
        gear: [sinker],
        tanks: [al80Spec],
        waterType: WaterType.salt,
        bodyWeightKg: 80,
      ),
    );
    expect(prediction.totalKg, 0);
  });

  test('breakdown terms label their sources', () {
    final model = fit([for (var i = 0; i < 20; i++) obs(index: i)]);
    final prediction = model.predict(rig(waterType: WaterType.fresh));
    final sources = {for (final t in prediction.terms) t.label: t.source};
    expect(sources['5mm Suit'], TermSource.measured);
    expect(
      prediction.terms.where((t) => t.source == TermSource.physics).length,
      2, // tank + water
    );
  });

  group('attribute-informed priors at the engine level', () {
    // With zero history, prediction = personal prior + gear priors + physics,
    // so a gear-prior difference flows straight through to the total. No
    // tanks and salt water keep the physics terms at zero, isolating gear.
    GearFeature suitFeature(String id, {String? style}) =>
        GearFeature.fromEquipment(
          id: id,
          type: EquipmentType.wetsuit,
          name: 'Suit $id',
          traits: GearBuoyancyTraits(primaryThicknessMm: 5, suitStyle: style),
        );

    RigSpec bareRig(GearFeature gear) => RigSpec(
      gear: [gear],
      tanks: const [],
      waterType: WaterType.salt,
      bodyWeightKg: 80,
    );

    test('a shorty predicts less lead than a full suit of equal thickness', () {
      final gear = {
        'full': suitFeature('full', style: 'full'),
        'shorty': suitFeature('shorty', style: 'shorty'),
      };
      final model = WeightPredictionEngine.fit(
        observations: const [],
        gearById: (id) => gear[id],
        bodyWeightKg: 80,
        now: now,
      );
      final fullKg = model.predict(bareRig(gear['full']!)).totalKg;
      final shortyKg = model.predict(bareRig(gear['shorty']!)).totalKg;
      // 5mm full = 5.0 kg prior; 5mm shorty = 5.0 * 0.55 = 2.75 kg.
      expect(fullKg - shortyKg, closeTo(5.0 - 5.0 * 0.55, 0.25));
    });

    test('drysuit shell material shifts an unseen-suit swap', () {
      GearFeature dry(String id, String material) => GearFeature.fromEquipment(
        id: id,
        type: EquipmentType.drysuit,
        name: 'Dry $id',
        traits: GearBuoyancyTraits(shellMaterial: material),
      );
      final gear = {
        'neo': dry('neo', 'neoprene'),
        'trilam': dry('trilam', 'trilaminate'),
      };
      final model = WeightPredictionEngine.fit(
        observations: const [],
        gearById: (id) => gear[id],
        bodyWeightKg: 80,
        now: now,
      );
      final neoKg = model.predict(bareRig(gear['neo']!)).totalKg;
      final trilamKg = model.predict(bareRig(gear['trilam']!)).totalKg;
      // neoprene 13.0 - trilaminate 9.0 = 4.0 kg.
      expect(neoKg - trilamKg, closeTo(4.0, 0.5));
    });
  });
}
