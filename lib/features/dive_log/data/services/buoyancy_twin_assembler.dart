import 'package:submersion/core/buoyancy/buoyancy_physics.dart';
import 'package:submersion/core/buoyancy/buoyancy_twin.dart';
import 'package:submersion/core/buoyancy/gear_feature.dart';
import 'package:submersion/core/buoyancy/twin_analyzer.dart';
import 'package:submersion/core/buoyancy/weight_prediction_engine.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/services/equipment_lead.dart';
import 'package:submersion/features/equipment/domain/services/gear_feature_mapper.dart';

/// The full result of running the twin for one dive: the raw series, the
/// derived outputs, and the wing lift capacity (when the rig records one).
class BuoyancyTwinOutcome {
  final BuoyancyTwinResult result;
  final TwinOutputs outputs;
  final double? wingLiftCapacityKg;
  const BuoyancyTwinOutcome({
    required this.result,
    required this.outputs,
    this.wingLiftCapacityKg,
  });
}

/// The depth-independent part of a rig: the suit (modeled separately) plus
/// the constant static terms and the total displaced mass used for the
/// water term. Shared by the logged-dive assembler and the planner.
class RigTerms {
  final TwinSuitInput suit;
  final List<TwinStaticTerm> staticTerms;
  final double totalMassKg;
  const RigTerms({
    required this.suit,
    required this.staticTerms,
    required this.totalMassKg,
  });
}

/// Builds [TwinInput] from a logged dive plus the diver's calibrated weight
/// model. Pure data assembly; no database or Riverpod dependency, so it is
/// unit-testable and can run inside a `compute` isolate boundary.
class BuoyancyTwinAssembler {
  /// Returns null when there is nothing to model (no tanks and no exposure
  /// suit -- e.g. an apnea dive).
  static TwinInput? assemble({
    required Dive dive,
    required Map<String, List<TankPressurePoint>> tankPressures,
    required FittedWeightModel model,
    required double? bodyWeightKg,
  }) {
    final suitItem = _exposureSuit(dive.equipment);
    if (dive.tanks.isEmpty && suitItem == null) return null;

    final tanks = <TwinTankInput>[];
    for (final t in dive.tanks) {
      final series = tankPressures[t.id];
      tanks.add(
        TwinTankInput(
          id: t.id,
          // 'tank' is a stable key the breakdown widget localizes via
          // _termLabel; a hardcoded 'Tank' would leak English. Real
          // preset/user names pass through untranslated, as intended.
          label: t.presetName ?? t.name ?? 'tank',
          presetName: t.presetName,
          volumeL: t.volume,
          workingPressureBar: t.workingPressure,
          material: t.material,
          o2Percent: t.gasMix.o2,
          hePercent: t.gasMix.he,
          startPressureBar: t.startPressure,
          endPressureBar: t.endPressure,
          pressureSeries: (series != null && series.isNotEmpty)
              ? [
                  for (final p in series)
                    TwinPressureSample(
                      timestamp: p.timestamp,
                      pressureBar: p.pressure,
                    ),
                ]
              : null,
        ),
      );
    }

    final rig = composeRigTerms(
      items: dive.equipment,
      tanks: tanks,
      model: model,
      waterType: dive.waterType,
      bodyWeightKg: bodyWeightKg,
    );

    return TwinInput(
      profile: [
        for (final p in dive.profile)
          TwinProfileSample(timestamp: p.timestamp, depthM: p.depth),
      ],
      tanks: tanks,
      suit: rig.suit,
      staticTerms: rig.staticTerms,
      leadKg: _carriedLead(dive),
      droppableLeadKg: droppableLeadKg(dive),
      environment: DiveEnvironment.forConditions(
        altitudeMeters: dive.altitude,
        waterType: dive.waterType,
      ),
      totalMassKg: rig.totalMassKg,
    );
  }

  /// Composes the suit input and the constant static terms from an equipment
  /// list, mirroring how [FittedWeightModel.predict] labels and sources each
  /// term. Reused by the Dive Planner and Weight Planner surfaces.
  static RigTerms composeRigTerms({
    required List<EquipmentItem> items,
    required List<TwinTankInput> tanks,
    required FittedWeightModel model,
    required WaterType? waterType,
    required double? bodyWeightKg,
  }) {
    final suitItem = _exposureSuit(items);
    final bodyMass = bodyWeightKg ?? BuoyancyPhysics.defaultBodyMassKg;

    var gearDryMass = 0.0;
    final staticTerms = <TwinStaticTerm>[];

    staticTerms.add(
      TwinStaticTerm(
        label: 'personal',
        kg: model.personalCoefficient,
        source: model.supportingDives >= 3
            ? TermSource.measured
            : TermSource.typeDefault,
      ),
    );

    for (final item in items) {
      final feature = _featureFor(item);
      if (feature == null) continue;
      gearDryMass += feature.dryMassKg;
      if (item.id == suitItem?.id) continue; // suit is modeled separately
      final fitted = model.coefficientsById[item.id];
      final usage = model.usageCounts[item.id] ?? 0;
      final TermSource source;
      if (fitted != null && usage >= 3) {
        source = TermSource.measured;
      } else if (feature.hasUserSpec) {
        source = TermSource.userSpec;
      } else {
        source = TermSource.typeDefault;
      }
      staticTerms.add(
        TwinStaticTerm(
          label: feature.label,
          kg: fitted ?? feature.priorKg,
          source: source,
        ),
      );
    }

    var tankDryMass = 0.0;
    for (final t in tanks) {
      tankDryMass += BuoyancyPhysics.tankDryMassKg(
        presetName: t.presetName,
        volumeL: t.volumeL,
        material: t.material,
      );
    }
    // Lead is deliberately absent from the displaced mass, whether it was
    // typed as weight rows or built into the rig as weights gear: the water
    // term scales displacement by mass, and lead at ~11x the density of water
    // displaces roughly a tenth of what its mass would imply.
    final totalMass = bodyMass + gearDryMass + tankDryMass;

    staticTerms.add(
      TwinStaticTerm(
        label: 'water',
        kg: BuoyancyPhysics.waterTermKg(
          waterType: waterType,
          totalMassKg: totalMass,
        ),
        source: TermSource.physics,
      ),
    );

    return RigTerms(
      suit: _suitInput(suitItem, model),
      staticTerms: staticTerms,
      totalMassKg: totalMass,
    );
  }

  /// Sum of droppable lead: belt and integrated rows are ditchable;
  /// backplate, trim, ankle, and mixed placements are treated as fixed.
  ///
  /// Gear-carried ballast contributes the share whose `weight_style` marks it
  /// ditchable; an unstyled weights item counts as fixed, which understates
  /// what the diver can drop rather than overstating it.
  static double droppableLeadKg(Dive dive) {
    final gear = EquipmentLead.droppableKg(dive.equipment);
    if (dive.weights.isNotEmpty) {
      var sum = 0.0;
      for (final w in dive.weights) {
        if (EquipmentLead.isDroppable(w.weightType)) sum += w.amountKg;
      }
      return sum + gear;
    }
    final legacy = dive.weightAmount ?? 0.0;
    final type = dive.weightType;
    return ((type == null || EquipmentLead.isDroppable(type)) ? legacy : 0.0) +
        gear;
  }

  /// Sum of droppable lead from a planned per-[WeightType] breakdown (keys are
  /// [WeightType.name], as produced by the Dive Planner). Belt and integrated
  /// are ditchable; every other placement (and any unrecognized key) is fixed.
  static double droppableLeadFromPlacement(Map<String, double> placement) {
    var sum = 0.0;
    for (final entry in placement.entries) {
      final type = WeightType.values
          .where((t) => t.name == entry.key)
          .firstOrNull;
      if (EquipmentLead.isDroppable(type)) sum += entry.value;
    }
    return sum;
  }

  static TwinSuitInput _suitInput(
    EquipmentItem? suitItem,
    FittedWeightModel m,
  ) {
    if (suitItem == null) {
      return const TwinSuitInput(
        kind: TwinSuitKind.none,
        anchorKg: 0,
        source: TermSource.typeDefault,
      );
    }
    final feature = _featureFor(suitItem)!;
    final fitted = m.coefficientsById[suitItem.id];
    final usage = m.usageCounts[suitItem.id] ?? 0;

    double anchor;
    TermSource source;
    if (fitted != null && fitted > 0 && usage >= 3) {
      anchor = fitted;
      source = TermSource.measured;
    } else if (feature.hasUserSpec && feature.priorKg > 0) {
      anchor = feature.priorKg;
      source = TermSource.userSpec;
    } else {
      anchor = feature.priorKg > 0
          ? feature.priorKg
          : (suitItem.type == EquipmentType.drysuit ? 10.0 : 4.0);
      source = TermSource.typeDefault;
    }

    return TwinSuitInput(
      kind: suitItem.type == EquipmentType.drysuit
          ? TwinSuitKind.drysuit
          : TwinSuitKind.wetsuit,
      anchorKg: anchor,
      source: source,
    );
  }

  /// Every kilogram of lead the diver carried: the typed weight rows (or the
  /// legacy scalar when there are none) plus ballast built into the rig as
  /// [EquipmentType.weights] gear.
  ///
  /// The two sources are additive, not a fallback ladder: a belt and a
  /// weighted backplate are different lead. Gear only contributes when it
  /// declares a mass, so rigs that list weights without numbers are
  /// unaffected. See [EquipmentLead].
  static double _carriedLead(Dive dive) {
    final typed = dive.weights.isNotEmpty
        ? dive.weights.fold(0.0, (sum, w) => sum + w.amountKg)
        : (dive.weightAmount ?? 0.0);
    return typed + EquipmentLead.totalKg(dive.equipment);
  }

  static EquipmentItem? _exposureSuit(List<EquipmentItem> items) {
    for (final item in items) {
      if (item.type == EquipmentType.wetsuit ||
          item.type == EquipmentType.drysuit) {
        return item;
      }
    }
    return null;
  }

  static GearFeature? _featureFor(EquipmentItem item) =>
      gearFeatureFromEquipment(item);
}
