import 'package:submersion/core/constants/tank_presets.dart';
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
    roleSource: tank.roleSource,
    volumeL: tank.volume,
    workingPressureBar: tank.workingPressure,
    tankMaterial: tank.material,
    startPressureBar: tank.startPressure,
    tankName: tank.name,
    tankOrder: tank.order,
    o2Percent: tank.gasMix.o2,
    hePercent: tank.gasMix.he,
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

  /// One saved cylinder as a plan tank, carrying its gas.
  ///
  /// The planner adds saved tanks one at a time rather than merging a whole
  /// configuration: a plan's cylinders are an input the diver is choosing,
  /// so each pick is a deliberate addition, not a fill of what was missing.
  /// Gas is carried for the same reason [apply] refuses it on a fill - in a
  /// plan the mix is the thing being chosen.
  ///
  /// A plan cylinder also needs a start pressure, or the planner can work out
  /// neither its turn pressure nor its minimum gas (#3603). A saved cylinder
  /// that never recorded one is filled the way a new tank is: to its rated
  /// working pressure, else the planner's usual 200 bar.
  DiveTank tankFromItem(
    CylinderConfigItem item, {
    required String id,
    int order = 0,
  }) {
    final tank = _fromItem(item, order, id);
    if (tank.startPressure != null) return tank;
    return tank.copyWith(
      startPressure: item.workingPressureBar ?? TankPresets.planFillPressureBar,
    );
  }

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
  ///
  /// [overwrites] lists claimed tanks whose specs differ from the
  /// configuration. They are applied only when [overwrite] is true, which a
  /// caller passes once the diver has confirmed them (issue #2563); [updated]
  /// counts them, and [kept] then excludes them. An overwrite may change a
  /// role the dive computer read off a transmitter's name (issue #3307); the
  /// configuration's specs are filled onto that tank only alongside it, so
  /// without [overwrite] the tank is left exactly as it was.
  ({
    List<DiveTank> tanks,
    int added,
    int kept,
    int updated,
    bool changed,
    List<OverwriteTank> overwrites,
  })
  apply({
    required List<DiveTank> tanks,
    required List<CylinderConfigItem> items,
    required String Function(int insertIndex) newId,
    bool overwrite = false,
  }) {
    final plan = applier.plan(
      existing: tanks.map(_toExisting).toList(),
      items: items,
    );

    final byId = {for (final tank in tanks) tank.id: tank};
    var insertIndex = 0;
    final applied = overwrite ? plan.overwrites : const <OverwriteTank>[];
    // Fills meant for a tank whose role change the diver has not accepted
    // would put one cylinder's specs on another.
    final pendingRoleChanges = {
      if (!overwrite)
        for (final o in plan.overwrites)
          if (o.role != null) o.tankId,
    };
    final ops = [
      for (final op in plan.ops)
        if (op is! FillTank || !pendingRoleChanges.contains(op.tankId)) op,
    ];

    // A fill and an overwrite of one tank touch disjoint columns (null versus
    // different), so applying both in sequence cannot clobber either.
    for (final op in [...ops, ...applied]) {
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
            clearRoleSource: op.clearRoleSource,
          );
        case InsertTank():
          final id = newId(insertIndex);
          byId[id] = _fromItem(op.item, op.tankOrder, id);
          insertIndex++;
        case OverwriteTank():
          final current = byId[op.tankId];
          if (current == null) continue;
          byId[op.tankId] = current.copyWith(
            volume: op.volumeL?.to,
            workingPressure: op.workingPressureBar?.to,
            material: op.tankMaterial?.to,
            name: op.tankName?.to,
            role: op.role?.to,
            gasMix: switch (op.gas?.to) {
              final gas? => GasMix(o2: gas.o2, he: gas.he),
              null => null,
            },
            // The diver accepted the configuration's role in place of the
            // one read off the transmitter's name.
            clearRoleSource: op.role != null,
            clearPresetName: op.changesCylinder,
          );
      }
    }

    final merged = byId.values.toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    return (
      tanks: merged,
      added: plan.insertedCount,
      kept: plan.keptCount - applied.length,
      updated: applied.length,
      changed: ops.isNotEmpty || applied.isNotEmpty,
      overwrites: plan.overwrites,
    );
  }
}
