import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

/// Lead a diver carries as gear rather than as typed per-dive weight rows.
///
/// Backplate-and-wing divers build their ballast into the rig -- weighted
/// backplates, weighted single-tank adapters, bolt-on trim blocks, dumpable
/// blocks -- record each as an [EquipmentType.weights] item, and leave the
/// dive's Weights section empty because there is no belt to describe.
///
/// That lead used to be invisible to every buoyancy surface. Weights items
/// are deliberately excluded from the gear features (lead is the quantity the
/// weight engine predicts, so it cannot also be a predictor), and nothing
/// else read them, so a rig carrying 30 lb of built-in ballast modeled as
/// though it carried none (issue #1103).
///
/// Pure functions over already-loaded values: the raw-row callers (weight
/// history) use [ballastKg] and [placementFor] directly, the entity callers
/// (buoyancy twin, planner) use the [EquipmentItem] helpers.
abstract final class EquipmentLead {
  /// Ballast one weights item contributes, in kg, or 0 when it declares no
  /// usable mass.
  ///
  /// Dry weight wins because it is unambiguously positive: a diver who typed
  /// `8` meaning "an 8 lb block" cannot accidentally invert the sign. Signed
  /// buoyancy is the fallback and is trusted only when negative, the one
  /// physically sensible sign for lead. Non-finite values (the numeric
  /// attribute fields parse with `double.tryParse`, which admits `Infinity`)
  /// are treated as absent.
  static double ballastKg({
    required double? dryWeightKg,
    required double? buoyancyKg,
  }) {
    if (dryWeightKg != null && dryWeightKg.isFinite && dryWeightKg > 0) {
      return dryWeightKg;
    }
    if (buoyancyKg != null && buoyancyKg.isFinite && buoyancyKg < 0) {
      return -buoyancyKg;
    }
    return 0.0;
  }

  /// The [WeightType] a weights item's `weight_style` attribute names, or
  /// null when unset or a future catalog value.
  static WeightType? placementFor(String? weightStyle) => switch (weightStyle) {
    'belt' => WeightType.belt,
    'integrated' => WeightType.integrated,
    'trim' => WeightType.trimWeights,
    'ankle' => WeightType.ankleWeights,
    _ => null,
  };

  /// Whether ballast in [type] can be ditched in an emergency. A null (unset
  /// or unrecognized) placement counts as fixed: understating how much weight
  /// the diver can drop is the safe direction to be wrong in.
  static bool isDroppable(WeightType? type) =>
      type == WeightType.belt || type == WeightType.integrated;

  /// Ballast [item] contributes; 0 for anything that is not weights gear.
  static double kgFor(EquipmentItem item) => item.type == EquipmentType.weights
      ? ballastKg(dryWeightKg: item.weightKg, buoyancyKg: item.buoyancyKg)
      : 0.0;

  /// Total gear-carried ballast across [items].
  static double totalKg(Iterable<EquipmentItem> items) =>
      items.fold(0.0, (sum, item) => sum + kgFor(item));

  /// The ditchable share of the gear-carried ballast across [items].
  static double droppableKg(Iterable<EquipmentItem> items) {
    var sum = 0.0;
    for (final item in items) {
      final placement = placementFor(
        item.attrText(EquipmentAttrKeys.weightStyle),
      );
      if (isDroppable(placement)) sum += kgFor(item);
    }
    return sum;
  }

  /// `WeightType.name` -> kg for gear-carried ballast that names a placement.
  /// Ballast with no placement is omitted rather than guessed at, so callers
  /// can tell "carried, placement unknown" from "carried on the belt".
  static Map<String, double> placementKg(Iterable<EquipmentItem> items) {
    final byType = <String, double>{};
    for (final item in items) {
      final kg = kgFor(item);
      if (kg <= 0) continue;
      final placement = placementFor(
        item.attrText(EquipmentAttrKeys.weightStyle),
      );
      if (placement == null) continue;
      byType.update(placement.name, (v) => v + kg, ifAbsent: () => kg);
    }
    return byType;
  }
}
