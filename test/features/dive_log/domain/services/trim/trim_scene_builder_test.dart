import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/buoyancy/buoyancy_twin.dart';
import 'package:submersion/core/buoyancy/trim/trim_moment.dart';
import 'package:submersion/core/buoyancy/trim/trim_spot.dart';
import 'package:submersion/core/buoyancy/weight_prediction_engine.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/dive_log/domain/services/trim/trim_placement.dart';
import 'package:submersion/features/dive_log/domain/services/trim/trim_scene_builder.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';

import '../../../presentation/widgets/buoyancy_outcome_fixture.dart';

/// A logged dive turned into trim elements (issue #5028).
void main() {
  final when = DateTime.utc(2026, 3, 15, 10);

  EquipmentItem item(
    String id,
    EquipmentType type, {
    Map<String, String> choices = const {},
    double? buoyancyKg,
    double? dryWeightKg,
  }) => EquipmentItem(
    id: id,
    name: id,
    type: type,
    attributes: [
      for (final e in choices.entries)
        EquipmentAttribute.curated(
          equipmentId: id,
          key: e.key,
          valueText: e.value,
        ),
      if (buoyancyKg != null)
        EquipmentAttribute.curated(
          equipmentId: id,
          key: EquipmentAttrKeys.buoyancyKg,
          valueNum: buoyancyKg,
        ),
      if (dryWeightKg != null)
        EquipmentAttribute.curated(
          equipmentId: id,
          key: EquipmentAttrKeys.dryWeightKg,
          valueNum: dryWeightKg,
        ),
    ],
  );

  TrimScene build(
    Dive dive, {
    List<TwinStaticTerm> terms = const [],
    List<TwinTankInput> tanks = const [],
    List<TwinSample>? samples,
    int? timestamp,
    double? heightCm,
  }) => buildTrimScene(
    dive: dive,
    outcome: buoyancyOutcome(
      staticTerms: terms,
      tanks: tanks,
      samples:
          samples ??
          const [
            TwinSample(
              timestamp: 0,
              depthM: 0,
              suitKg: 3,
              tanksKg: 0,
              netKg: 2,
            ),
            TwinSample(
              timestamp: 60,
              depthM: 5,
              suitKg: 3,
              tanksKg: 0,
              netKg: 1.8,
            ),
          ],
    ),
    timestamp: timestamp,
    heightCm: heightCm,
  );

  TrimElement only(TrimScene scene, TrimElementKind kind) =>
      scene.elements.singleWhere((e) => e.kind == kind);

  test('typed weights become lead elements at their spots', () {
    final scene = build(
      Dive(
        id: 'd1',
        dateTime: when,
        weights: const [
          DiveWeight(
            id: 'w1',
            diveId: 'd1',
            weightType: WeightType.integrated,
            amountKg: 4,
            side: WeightSide.left,
          ),
          DiveWeight(
            id: 'w2',
            diveId: 'd1',
            weightType: WeightType.trimWeights,
            amountKg: 2,
          ),
        ],
      ),
    );
    final lead = scene.elements
        .where((e) => e.kind == TrimElementKind.lead)
        .toList();
    expect(lead.map((e) => e.spot), [
      TrimSpot.hipPockets,
      TrimSpot.trimPockets,
    ]);
    expect(lead.first.sinkKg, 4);
    expect(lead.first.lateral, TrimLateral.left);
    expect(lead.first.weightType, WeightType.integrated);
  });

  test('the legacy single weight is used only with no typed weights', () {
    final legacy = build(
      Dive(
        id: 'd1',
        dateTime: when,
        weightAmount: 5,
        weightType: WeightType.belt,
      ),
    );
    expect(only(legacy, TrimElementKind.lead).spot, TrimSpot.waist);
    expect(only(legacy, TrimElementKind.lead).sinkKg, 5);

    final typed = build(
      Dive(
        id: 'd1',
        dateTime: when,
        weightAmount: 5,
        weights: const [
          DiveWeight(
            id: 'w1',
            diveId: 'd1',
            weightType: WeightType.trimWeights,
            amountKg: 2,
          ),
        ],
      ),
    );
    expect(only(typed, TrimElementKind.lead).sinkKg, 2);
  });

  test("weights gear becomes lead at its style's spot", () {
    final plate = item(
      'plate',
      EquipmentType.weights,
      choices: const {'weight_style': 'trim'},
      dryWeightKg: 2,
    );
    final scene = build(
      Dive(
        id: 'd1',
        dateTime: when,
        gear: [GearLink(item: plate)],
      ),
    );
    final lead = only(scene, TrimElementKind.lead);
    expect(lead.spot, TrimSpot.trimPockets);
    expect(lead.itemId, 'plate');
    expect(lead.sinkKg, greaterThan(1.5));
  });

  test('gear terms are placed by item id and use the prior', () {
    final light = item('light', EquipmentType.light);
    final scene = build(
      Dive(
        id: 'd1',
        dateTime: when,
        gear: [GearLink(item: light)],
      ),
      terms: const [
        TwinStaticTerm(
          label: 'light',
          kg: -2.0,
          source: TermSource.measured,
          itemId: 'light',
          priorKg: -0.5,
        ),
      ],
    );
    final gear = only(scene, TrimElementKind.gear);
    expect(gear.spot, TrimSpot.hand);
    expect(gear.sinkKg, 0.5);
  });

  test('fins with no entered buoyancy use the blade-style default', () {
    final fins = item(
      'fins',
      EquipmentType.fins,
      choices: const {'blade_style': 'vented'},
    );
    final scene = build(
      Dive(
        id: 'd1',
        dateTime: when,
        gear: [GearLink(item: fins)],
      ),
    );
    final gear = only(scene, TrimElementKind.gear);
    expect(gear.spot, TrimSpot.fins);
    expect(gear.sinkKg, kVentedFinSinkKg);
  });

  test('fins with entered buoyancy use it', () {
    final fins = item('fins', EquipmentType.fins, buoyancyKg: -0.9);
    final scene = build(
      Dive(
        id: 'd1',
        dateTime: when,
        gear: [GearLink(item: fins)],
      ),
      terms: const [
        TwinStaticTerm(
          label: 'fins',
          kg: -0.9,
          source: TermSource.userSpec,
          itemId: 'fins',
          priorKg: -0.9,
        ),
      ],
    );
    expect(only(scene, TrimElementKind.gear).sinkKg, closeTo(0.9, 1e-9));
  });

  test('camera accessories follow the camera', () {
    final camera = item('cam', EquipmentType.camera);
    final arm = item('arm', EquipmentType.floatArm);
    final scene = build(
      Dive(
        id: 'd1',
        dateTime: when,
        gear: [
          GearLink(item: camera),
          GearLink(item: arm),
        ],
      ),
    );
    final byId = {for (final e in scene.elements) e.itemId: e};
    expect(byId['arm']!.spot, byId['cam']!.spot);
    expect(byId['arm']!.lateral, byId['cam']!.lateral);
  });

  test("an assembly's parts weigh as one element at its spot", () {
    final reg = item('reg', EquipmentType.regulator);
    final second = item('second', EquipmentType.secondStage);
    final scene = build(
      Dive(
        id: 'd1',
        dateTime: when,
        gear: [
          GearLink(item: reg),
          GearLink(item: second, viaEquipmentId: 'reg'),
        ],
      ),
      terms: const [
        TwinStaticTerm(
          label: 'second',
          kg: -0.4,
          source: TermSource.typeDefault,
          itemId: 'second',
          priorKg: -0.4,
        ),
      ],
    );
    final gear = scene.elements
        .where((e) => e.kind == TrimElementKind.gear)
        .toList();
    expect(gear.single.itemId, 'reg');
    expect(gear.single.sinkKg, closeTo(0.4, 1e-9));
  });

  test('tank buoyancy follows the timestamp', () {
    const tank = TwinTankInput(
      id: 't1',
      label: 'AL80',
      volumeL: 11.1,
      workingPressureBar: 207,
      material: TankMaterial.aluminum,
      startPressureBar: 200,
      endPressureBar: 50,
    );
    final dive = Dive(
      id: 'd1',
      dateTime: when,
      tanks: const [DiveTank(id: 't1', volume: 11.1)],
    );
    final start = build(dive, tanks: const [tank], timestamp: 0);
    final end = build(dive, tanks: const [tank], timestamp: 60);
    expect(
      only(end, TrimElementKind.tank).sinkKg,
      lessThan(only(start, TrimElementKind.tank).sinkKg),
    );
    expect(only(start, TrimElementKind.tank).spot, TrimSpot.backTank);
  });

  test('the model net follows the timestamp, the anchor without one', () {
    final dive = Dive(id: 'd1', dateTime: when);
    expect(build(dive, timestamp: 0).modelNetKg, 2);
    expect(build(dive).modelNetKg, 1.8);
    expect(build(dive).timestamp, 60);
  });

  test('a jacket BCD lifts at the float point, a wing at the wing', () {
    Dive with_(String style) => Dive(
      id: 'd1',
      dateTime: when,
      gear: [
        GearLink(
          item: item('bcd', EquipmentType.bcd, choices: {'bcd_style': style}),
        ),
      ],
    );
    expect(build(with_('jacket')).liftSpot, TrimSpot.floatPoint);
    expect(build(with_('wing')).liftSpot, TrimSpot.wing);
    expect(build(Dive(id: 'd1', dateTime: when)).liftSpot, TrimSpot.floatPoint);
  });

  test('no height on file uses 175 cm', () {
    expect(build(Dive(id: 'd1', dateTime: when)).body.heightM, 1.75);
    expect(
      build(Dive(id: 'd1', dateTime: when), heightCm: 190).body.heightM,
      1.9,
    );
  });
}
