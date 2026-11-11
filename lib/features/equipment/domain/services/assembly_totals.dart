import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/services/components_index.dart';
import 'package:submersion/features/equipment/domain/services/gear_expander.dart';
import 'package:submersion/features/equipment/domain/services/gear_tree.dart';

/// One measurement summed across an assembly's parts: the total in kg and
/// how many parts declared a value toward it.
typedef PartsSum = ({double kg, int parts});

/// What an assembly's parts add up to (issue #4443): a weight harness with
/// two pockets of lead shows the lead of both, without the diver doing the
/// sum by hand and typing it on the harness.
///
/// The parts counted are exactly the ones a dive would count. The assembly
/// is expanded with [GearExpander], as attaching it to a dive does, and the
/// rows [GearTree.rolledUpIds] names are skipped, as the buoyancy twin skips
/// them: a nested assembly whose parts come along declares nothing itself,
/// a retired or lost part (and everything below it) is not carried, and a
/// part shared by two nested assemblies is carried once. So the total on the
/// harness's page is the figure the harness adds to a dive.
///
/// The assembly's own Buoyancy and Dry weight are never part of the sum and
/// are left as the diver typed them.
class AssemblyTotals {
  /// Parts counted: every carried part that is not itself rolled up, with
  /// or without a value.
  final int partCount;

  /// Summed buoyancy, or null when no counted part declares one.
  final PartsSum? buoyancy;

  /// Summed dry weight, or null when no counted part declares one.
  final PartsSum? dryWeight;

  const AssemblyTotals({
    required this.partCount,
    this.buoyancy,
    this.dryWeight,
  });

  static const empty = AssemblyTotals(partCount: 0);

  /// Whether there is any total to show.
  bool get hasAny => buoyancy != null || dryWeight != null;

  /// Totals for [assemblyId] from the component template in [index].
  /// [itemFor] resolves a part's attributes; a part it cannot resolve is
  /// skipped, and [isActive] should be false for it so nothing below it is
  /// walked either.
  static AssemblyTotals of(
    String assemblyId, {
    required ComponentsIndex index,
    required EquipmentItem? Function(String id) itemFor,
    required bool Function(String id) isActive,
  }) {
    final rows = GearExpander.expand(
      additions: [(equipmentId: assemblyId, viaSetId: null)],
      index: index,
      existing: const [],
      isActive: isActive,
    );
    final rolledUp = GearTree.rolledUpIds(rows);

    var count = 0;
    var buoyancyKg = 0.0;
    var buoyancyParts = 0;
    var dryKg = 0.0;
    var dryParts = 0;
    for (final row in rows) {
      final id = row.equipmentId;
      if (id == assemblyId || rolledUp.contains(id)) continue;
      final part = itemFor(id);
      if (part == null) continue;
      count++;
      final buoyancy = part.buoyancyKg;
      if (buoyancy != null && buoyancy.isFinite) {
        buoyancyKg += buoyancy;
        buoyancyParts++;
      }
      final dry = part.weightKg;
      if (dry != null && dry.isFinite) {
        dryKg += dry;
        dryParts++;
      }
    }

    return AssemblyTotals(
      partCount: count,
      buoyancy: buoyancyParts == 0
          ? null
          : (kg: buoyancyKg, parts: buoyancyParts),
      dryWeight: dryParts == 0 ? null : (kg: dryKg, parts: dryParts),
    );
  }
}
