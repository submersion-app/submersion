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

/// The result of planning an apply: the operations to persist, plus the
/// counts a caller reports back to the diver.
class CylinderConfigPlan {
  final List<CylinderConfigOp> ops;
  final int insertedCount;
  final int keptCount;

  const CylinderConfigPlan({
    required this.ops,
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

  CylinderConfigPlan plan({
    required List<ExistingTank> existing,
    required List<CylinderConfigItem> items,
  }) {
    final ordered = [...items]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final claimed = <String>{};
    final ops = <CylinderConfigOp>[];
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
    }

    return CylinderConfigPlan(
      ops: ops,
      insertedCount: inserted,
      keptCount: kept,
    );
  }
}
