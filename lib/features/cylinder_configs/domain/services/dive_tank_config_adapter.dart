import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config_item.dart';
import 'package:submersion/features/cylinder_configs/domain/services/cylinder_config_applier.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Applies a cylinder configuration to an in-memory list of dive tanks.
///
/// The dive edit page holds its cylinders as unsaved local state and persists
/// them only when the diver taps Save, so applying a configuration must
/// produce a NEW list rather than writing to dive_tanks. Writing straight to
/// the database would bypass the page's dirty tracking and would persist
/// changes even if the diver then cancelled.
///
/// All merge rules live in [CylinderConfigApplier]; this only translates
/// between DiveTank and the applier's ExistingTank view, and materialises the
/// resulting ops.
class DiveTankConfigAdapter {
  const DiveTankConfigAdapter({this.applier = const CylinderConfigApplier()});

  final CylinderConfigApplier applier;

  ExistingTank _toExisting(DiveTank tank) => ExistingTank(
    id: tank.id,
    tankRole: tank.role,
    volumeL: tank.volume,
    workingPressureBar: tank.workingPressure,
    tankMaterial: tank.material,
    startPressureBar: tank.startPressure,
    tankName: tank.name,
    tankOrder: tank.order,
  );

  DiveTank _fromItem(CylinderConfigItem item, int order, String id) => DiveTank(
    id: id,
    name: item.label,
    volume: item.volumeL,
    workingPressure: item.workingPressureBar,
    startPressure: item.defaultStartPressureBar,
    gasMix: GasMix(o2: item.o2Percent, he: item.hePercent),
    role: item.tankRole,
    material: item.tankMaterial,
    order: order,
  );

  /// Returns the merged tank list, the counts to report to the diver, and
  /// whether anything actually changed.
  ///
  /// [changed] is derived from the plan's ops, not from the counts: a repeat
  /// apply matches every role and so reports a non-zero [kept] while doing no
  /// work at all. Callers use it to avoid marking a form dirty for a merge
  /// that altered nothing.
  ///
  /// [newId] mints an id for each inserted tank; the caller supplies it so
  /// this stays pure and testable (no Uuid, no DateTime.now()).
  ({List<DiveTank> tanks, int added, int kept, bool changed}) apply({
    required List<DiveTank> tanks,
    required List<CylinderConfigItem> items,
    required String Function(int insertIndex) newId,
  }) {
    final plan = applier.plan(
      existing: tanks.map(_toExisting).toList(),
      items: items,
    );

    final byId = {for (final tank in tanks) tank.id: tank};
    var insertIndex = 0;

    for (final op in plan.ops) {
      switch (op) {
        case FillTank():
          final current = byId[op.tankId];
          if (current == null) continue;
          byId[op.tankId] = current.copyWith(
            volume: op.volumeL,
            workingPressure: op.workingPressureBar,
            material: op.tankMaterial,
            startPressure: op.startPressureBar,
            name: op.tankName,
          );
        case InsertTank():
          final id = newId(insertIndex);
          byId[id] = _fromItem(op.item, op.tankOrder, id);
          insertIndex++;
      }
    }

    final merged = byId.values.toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    return (
      tanks: merged,
      added: plan.insertedCount,
      kept: plan.keptCount,
      changed: plan.ops.isNotEmpty,
    );
  }
}
