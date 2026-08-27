import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/buoyancy/buoyancy_twin.dart';
import 'package:submersion/core/buoyancy/twin_analyzer.dart';
import 'package:submersion/core/buoyancy/weight_prediction_engine.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_weight_entry_providers.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/weight_planner/presentation/providers/plan_buoyancy_twin_provider.dart';
import 'package:submersion/features/weight_planner/presentation/providers/weight_planner_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  PlanSegment seg(SegmentType type, double start, double end, int dur) =>
      PlanSegment(
        id: '$type$start',
        type: type,
        startDepth: start,
        endDepth: end,
        durationSeconds: dur,
        tankId: 't1',
        gasMix: const GasMix(o2: 21),
      );

  final plan = [
    seg(SegmentType.descent, 0, 30, 60),
    seg(SegmentType.bottom, 30, 30, 1200),
    seg(SegmentType.ascent, 30, 5, 150),
    seg(SegmentType.safetyStop, 5, 5, 180),
    seg(SegmentType.ascent, 5, 0, 30),
  ];

  test('synthesized profile has monotonic timestamps', () {
    final profile = synthesizePlanProfile(plan);
    for (var i = 1; i < profile.length; i++) {
      expect(profile[i].timestamp, greaterThan(profile[i - 1].timestamp));
    }
  });

  test('bottom segment produces interior samples every 30 s', () {
    final profile = synthesizePlanProfile(plan);
    final bottom = profile
        .where((s) => s.depthM == 30 && s.timestamp > 60 && s.timestamp < 1260)
        .toList();
    expect(bottom.length, greaterThan(30)); // ~38 interior points
    expect(bottom[1].timestamp - bottom[0].timestamp, 30);
  });

  test('empty plan yields an empty profile', () {
    expect(synthesizePlanProfile(const []), isEmpty);
  });

  test('skips zero-duration segments to keep timestamps monotonic', () {
    // The segment editor defaults a blank/invalid duration field to 0, so a
    // 0-minute leg is reachable. It must not emit a duplicate timestamp.
    final withZero = [
      seg(SegmentType.descent, 0, 30, 60),
      seg(SegmentType.bottom, 30, 30, 0), // blank duration field
      seg(SegmentType.ascent, 30, 5, 150),
      seg(SegmentType.safetyStop, 5, 5, 180),
    ];
    final profile = synthesizePlanProfile(withZero);
    for (var i = 1; i < profile.length; i++) {
      expect(
        profile[i].timestamp,
        greaterThan(profile[i - 1].timestamp),
        reason: 'a zero-duration leg duplicated a timestamp at sample $i',
      );
    }
  });

  test('anchor detection finds the safety stop', () {
    final model = WeightPredictionEngine.fit(
      observations: const [],
      gearById: (_) => null,
      bodyWeightKg: 75,
    );
    final rig = _rigTerms(model);
    final input = TwinInput(
      profile: synthesizePlanProfile(plan),
      tanks: const [
        TwinTankInput(
          id: 't1',
          label: 'al80',
          presetName: 'al80',
          volumeL: 11,
          workingPressureBar: 207,
          material: TankMaterial.aluminum,
          o2Percent: 21,
          startPressureBar: 200,
          endPressureBar: 60,
        ),
      ],
      suit: rig.suit,
      staticTerms: rig.staticTerms,
      leadKg: 6,
      droppableLeadKg: 6,
      environment: DiveEnvironment.forConditions(),
      totalMassKg: rig.totalMassKg,
    );
    final outputs = TwinAnalyzer.analyze(runBuoyancyTwin(input));
    expect(outputs.verdict.anchor.kind, TwinAnchorKind.detectedStop);
    expect(outputs.verdict.anchor.depthM, closeTo(5.0, 0.5));
  });

  test('planned lead is a total: gear ballast is not added on top', () async {
    // plannedWeightKg is only ever written as a snapshot of
    // prediction.totalKg, and since #1103 that prediction is trained on
    // observations whose carriedKg already includes ballast built into the
    // rig. Adding EquipmentLead here would double-count it, so the planned
    // figure must pass through untouched even when the rig carries 5 kg of
    // weights-type gear.
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    // settingsProvider reaches the database through DiverRepository, and the
    // plan notifier is built from settings; the other cases in this file are
    // pure, so the database is set up only for this one.
    await setUpTestDatabase();
    addTearDown(tearDownTestDatabase);

    const plate = EquipmentItem(
      id: 'plate',
      name: 'Weighted backplate',
      type: EquipmentType.weights,
      attributes: [
        EquipmentAttribute(
          id: 'a1',
          equipmentId: 'plate',
          key: EquipmentAttrKeys.dryWeightKg,
          valueNum: 5.0,
        ),
      ],
    );

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        allEquipmentProvider.overrideWith((ref) async => [plate]),
        latestDiverWeightProvider.overrideWith((ref) async => null),
        weightCalibrationProvider.overrideWith(
          (ref) async => WeightPredictionEngine.fit(
            observations: const [],
            gearById: (_) => null,
            bodyWeightKg: 75,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    // Warm the async overrides the provider reads via valueOrNull.
    await container.read(allEquipmentProvider.future);
    await container.read(weightCalibrationProvider.future);
    await container.read(latestDiverWeightProvider.future);

    final notifier = container.read(divePlanNotifierProvider.notifier);
    notifier.addTank(
      const DiveTank(
        id: 't1',
        volume: 11,
        workingPressure: 207,
        startPressure: 200,
        material: TankMaterial.aluminum,
        presetName: 'al80',
        gasMix: GasMix(o2: 21),
      ),
    );
    for (final s in plan) {
      notifier.addSegment(s);
    }
    notifier.setEquipmentIds(const ['plate']);
    notifier.setPlannedWeight(6.0, null);

    final outcome = container.read(planBuoyancyTwinProvider);
    expect(outcome, isNotNull);
    expect(outcome!.result.input.leadKg, closeTo(6.0, 1e-9));
  });
}

// Minimal rig terms with no suit so the test does not depend on gear.
({TwinSuitInput suit, List<TwinStaticTerm> staticTerms, double totalMassKg})
_rigTerms(FittedWeightModel model) => (
  suit: const TwinSuitInput(
    kind: TwinSuitKind.none,
    anchorKg: 0,
    source: TermSource.typeDefault,
  ),
  staticTerms: [
    TwinStaticTerm(
      label: 'personal',
      kg: model.personalCoefficient,
      source: TermSource.typeDefault,
    ),
  ],
  totalMassKg: 90,
);
