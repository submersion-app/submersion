import 'package:drift/drift.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/export/csv/codec/tank_capacity.dart';

/// Above this many litres a cylinder's stored volume can only be cubic feet
/// typed as water (v368, issue #4534): no scuba cylinder is this large, while
/// the smallest imperial figure stored that way (a 3 cu ft spare air) lands
/// near 85 L. Gas banks, typically 50 L, stay below it.
const double cylinderVolumeRepairThresholdLiters = 80;

/// The unit a save stores with attribute [key]: [valueUnit] as given, or
/// `liters` for a cylinder volume above the repair line, which a diver
/// entered on purpose since v368 and [repairCylinderVolumeCubicFeet] must
/// never touch when it repeats after a sync apply. Every writer of attribute
/// rows (the repository, the agent's plan) applies it, so they agree.
String? stampedCylinderVolumeUnit(
  String key,
  double? valueNum,
  String? valueUnit,
) =>
    valueUnit ??
    (key == 'volume_l' && (valueNum ?? 0) > cylinderVolumeRepairThresholdLiters
        ? VolumeUnit.liters.name
        : null);

/// Rewrites every cylinder volume an imperial diver typed in cubic feet
/// before v368, and returns how many it rewrote.
///
/// The equipment form read the figure as cubic feet of WATER, so an AL80
/// typed as 77.4 was stored as about 2192 L. The stored litres convert back
/// to the figure typed exactly, which is then the cylinder's rated gas
/// capacity at its working pressure (200 bar assumed without one), the way
/// the rest of the app reads cubic feet. A repaired volume is under the
/// threshold, so running this again changes nothing.
///
/// A row with a `value_unit` was saved by a build that knows cubic feet
/// mean gas capacity, so it is never touched: a cylinder above the line
/// saved since v368 is stamped `liters` (`EquipmentRepository.saveAttributes`)
/// and stays as entered when the repair repeats after a sync apply.
///
/// The sync stamp (`updated_at`, `hlc`) does not move: every device runs this
/// same rewrite, and a row that arrives later from a peer below v368 is
/// repaired after the apply (`SyncService._repairLegacyPeerRows`).
///
/// Raw SQL, as the other ladder helpers, so it keeps compiling against any
/// later shape of the generated classes. The conversion is the app's own
/// (preset-aware), which SQL cannot express, so rows are rewritten one by
/// one; there are only ever a handful.
Future<int> repairCylinderVolumeCubicFeet(DatabaseConnectionUser db) async {
  final rows = await db
      .customSelect(
        'SELECT v.id AS id, v.value_num AS litres, '
        '(SELECT p.value_num FROM equipment_attributes p '
        'WHERE p.equipment_id = v.equipment_id '
        "AND p.attr_key = 'working_pressure_bar' AND p.is_custom = 0) "
        'AS pressure '
        'FROM equipment_attributes v '
        'JOIN equipment e ON e.id = v.equipment_id '
        "WHERE v.attr_key = 'volume_l' AND v.is_custom = 0 "
        'AND v.value_unit IS NULL '
        "AND e.type = 'tank' AND v.value_num > ?",
        variables: [
          const Variable<double>(cylinderVolumeRepairThresholdLiters),
        ],
      )
      .get();
  for (final row in rows) {
    final typedCuft = VolumeUnit.liters.convert(
      row.read<double>('litres'),
      VolumeUnit.cubicFeet,
    );
    await db.customUpdate(
      'UPDATE equipment_attributes SET value_num = ? WHERE id = ?',
      variables: [
        Variable<double>(
          volumeLitersFromCapacity(typedCuft, row.read<double?>('pressure')),
        ),
        Variable<String>(row.read<String>('id')),
      ],
    );
  }
  return rows.length;
}
