import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config_item.dart';

/// The applier's read-only view of an existing dive_tanks row.
class ExistingTank {
  final String id;
  final TankRole tankRole;
  final double? volumeL;
  final double? workingPressureBar;
  final TankMaterial? tankMaterial;
  final double? startPressureBar;
  final String? tankName;
  final int tankOrder;

  const ExistingTank({
    required this.id,
    required this.tankRole,
    this.volumeL,
    this.workingPressureBar,
    this.tankMaterial,
    this.startPressureBar,
    this.tankName,
    this.tankOrder = 0,
  });
}

sealed class CylinderConfigOp {
  const CylinderConfigOp();
}

/// Create a new dive_tanks row from [item] at [tankOrder].
class InsertTank extends CylinderConfigOp {
  final CylinderConfigItem item;
  final int tankOrder;

  const InsertTank({required this.item, required this.tankOrder});
}

/// Fill columns that are NULL on an existing dive_tanks row. Every field here
/// is nullable and null means "leave this column alone".
///
/// There are deliberately no o2Percent or hePercent fields. dive_tanks
/// defaults them to 21.0 and 0.0, so a tank reading air is indistinguishable
/// from a tank nobody filled in -- there is no null to test against, and
/// therefore no honest way to detect "unset". Omitting the fields makes
/// overwriting a gas mix unexpressible rather than merely discouraged.
/// Absent gas on a dive is a nuisance; wrong gas is a safety-relevant
/// falsehood in a logbook divers plan future dives from.
class FillTank extends CylinderConfigOp {
  final String tankId;
  final double? volumeL;
  final double? workingPressureBar;
  final TankMaterial? tankMaterial;
  final double? startPressureBar;
  final String? tankName;

  const FillTank({
    required this.tankId,
    this.volumeL,
    this.workingPressureBar,
    this.tankMaterial,
    this.startPressureBar,
    this.tankName,
  });

  bool get isEmpty =>
      volumeL == null &&
      workingPressureBar == null &&
      tankMaterial == null &&
      startPressureBar == null &&
      tankName == null;
}

/// One spec column whose value on the dive differs from the configuration.
class SpecChange<T> {
  final T from;
  final T to;

  const SpecChange(this.from, this.to);
}

/// Replace spec columns that already hold a DIFFERENT value on an existing
/// row. Every field is nullable and null means "this column already agrees".
///
/// Never part of [CylinderConfigPlan.ops]: a FillTank only writes into a
/// gap, but this replaces something the diver or a dive computer put there,
/// so callers show the diver these changes and apply them only on consent
/// (issue #2563). Like [FillTank] it has no gas fields, and no start
/// pressure either: that is a reading of this dive, not a property of the
/// cylinder a configuration describes.
class OverwriteTank extends CylinderConfigOp {
  final String tankId;
  final TankRole tankRole;
  final SpecChange<double>? volumeL;
  final SpecChange<double>? workingPressureBar;
  final SpecChange<TankMaterial>? tankMaterial;
  final SpecChange<String>? tankName;

  const OverwriteTank({
    required this.tankId,
    required this.tankRole,
    this.volumeL,
    this.workingPressureBar,
    this.tankMaterial,
    this.tankName,
  });

  bool get isEmpty =>
      volumeL == null &&
      workingPressureBar == null &&
      tankMaterial == null &&
      tankName == null;

  /// Whether the cylinder itself changes, not just its label. A tank preset
  /// name no longer describes a cylinder whose size or material changed.
  bool get changesCylinder =>
      volumeL != null || workingPressureBar != null || tankMaterial != null;
}

/// The result of planning an apply: the operations to persist, the
/// overwrites to offer the diver, plus the counts a caller reports back.
class CylinderConfigPlan {
  final List<CylinderConfigOp> ops;

  /// Differences on claimed tanks that [ops] deliberately leaves alone.
  final List<OverwriteTank> overwrites;
  final int insertedCount;
  final int keptCount;

  const CylinderConfigPlan({
    required this.ops,
    this.overwrites = const [],
    required this.insertedCount,
    required this.keptCount,
  });

  bool get isNoOp => insertedCount == 0 && keptCount == 0;
}

/// Merges a cylinder configuration into a dive's existing cylinders.
///
/// Pure: no database, no DateTime.now(). Callers persist the returned ops.
/// Mirrors ServiceDueEngine, so the merge rules can be tested exhaustively
/// without a database fixture.
class CylinderConfigApplier {
  const CylinderConfigApplier();

  // Specs reach both sides through unit conversion (a cylinder entered in
  // cubic feet or psi), so an exact comparison would offer to "change" a
  // cylinder to the value it already holds.
  static const _volumeToleranceL = 0.01;
  static const _pressureToleranceBar = 0.5;

  /// A change only when both sides hold a value: a null on the dive is a
  /// fill, and a null in the configuration has nothing to offer.
  static SpecChange<double>? _differs(
    double? current,
    double? wanted,
    double tolerance,
  ) {
    if (current == null || wanted == null) return null;
    if ((current - wanted).abs() <= tolerance) return null;
    return SpecChange(current, wanted);
  }

  CylinderConfigPlan plan({
    required List<ExistingTank> existing,
    required List<CylinderConfigItem> items,
  }) {
    final ordered = [...items]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final claimed = <String>{};
    final ops = <CylinderConfigOp>[];
    final overwrites = <OverwriteTank>[];
    var inserted = 0;
    var kept = 0;

    var nextOrder = existing.isEmpty
        ? 0
        : existing.map((t) => t.tankOrder).reduce((a, b) => a > b ? a : b) + 1;

    for (final item in ordered) {
      // First unclaimed existing tank with the same role. Roles are not
      // unique -- a CCR diver routinely carries two bailout cylinders -- so
      // claiming greedily in order is what makes "config has 2 bailouts,
      // dive already has 1" resolve to keep-one-add-one rather than
      // duplicating or clobbering.
      ExistingTank? match;
      for (final tank in existing) {
        if (tank.tankRole == item.tankRole && !claimed.contains(tank.id)) {
          match = tank;
          break;
        }
      }

      if (match == null) {
        ops.add(InsertTank(item: item, tankOrder: nextOrder));
        nextOrder++;
        inserted++;
        continue;
      }

      claimed.add(match.id);
      kept++;

      final fill = FillTank(
        tankId: match.id,
        volumeL: match.volumeL == null ? item.volumeL : null,
        workingPressureBar: match.workingPressureBar == null
            ? item.workingPressureBar
            : null,
        tankMaterial: match.tankMaterial == null ? item.tankMaterial : null,
        startPressureBar: match.startPressureBar == null
            ? item.defaultStartPressureBar
            : null,
        tankName: match.tankName == null ? item.label : null,
      );
      if (!fill.isEmpty) ops.add(fill);

      final label = item.label?.trim();
      final overwrite = OverwriteTank(
        tankId: match.id,
        tankRole: match.tankRole,
        volumeL: _differs(match.volumeL, item.volumeL, _volumeToleranceL),
        workingPressureBar: _differs(
          match.workingPressureBar,
          item.workingPressureBar,
          _pressureToleranceBar,
        ),
        tankMaterial:
            match.tankMaterial != null &&
                item.tankMaterial != null &&
                match.tankMaterial != item.tankMaterial
            ? SpecChange(match.tankMaterial!, item.tankMaterial!)
            : null,
        tankName:
            match.tankName != null &&
                label != null &&
                label.isNotEmpty &&
                match.tankName!.trim() != label
            ? SpecChange(match.tankName!, label)
            : null,
      );
      if (!overwrite.isEmpty) overwrites.add(overwrite);
    }

    return CylinderConfigPlan(
      ops: ops,
      overwrites: overwrites,
      insertedCount: inserted,
      keptCount: kept,
    );
  }
}
