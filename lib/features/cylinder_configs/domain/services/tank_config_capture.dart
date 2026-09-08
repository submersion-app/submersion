import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config_item.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Builds configuration items from an in-memory tank list: the reverse of
/// `DiveTankConfigAdapter`, so a rig entered once in the planner can be saved
/// and picked again.
///
/// Mapping is field for field. `endPressure`, `computerId`, `presetName`,
/// `decoSwitchDepth` and `isTravelGas` are not part of a configuration - they
/// describe one dive or one plan, not the cylinder - and are dropped.
///
/// Pure: [newId] mints item ids and [now] stamps them, so this stays
/// testable. An empty id is also acceptable, since the repository mints one
/// on save.
class TankConfigCapture {
  const TankConfigCapture();

  List<CylinderConfigItem> fromTanks({
    required List<DiveTank> tanks,
    required String configId,
    required String Function(int index) newId,
    DateTime? now,
  }) {
    final stamp = now ?? DateTime.now();
    final sorted = List<DiveTank>.from(tanks)
      ..sort((a, b) => a.order.compareTo(b.order));
    return [
      for (var i = 0; i < sorted.length; i++)
        CylinderConfigItem(
          id: newId(i),
          configId: configId,
          sortOrder: i,
          label: sorted[i].name,
          tankRole: sorted[i].role,
          volumeL: sorted[i].volume,
          workingPressureBar: sorted[i].workingPressure,
          tankMaterial: sorted[i].material,
          o2Percent: sorted[i].gasMix.o2,
          hePercent: sorted[i].gasMix.he,
          defaultStartPressureBar: sorted[i].startPressure,
          createdAt: stamp,
          updatedAt: stamp,
        ),
    ];
  }
}
