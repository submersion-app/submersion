import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_colors.dart';
import 'package:submersion/features/equipment/domain/models/recent_equipment_colors.dart';

/// The custom colours already on a diver's gear (issue #4537), which the
/// item colour sheet offers beside the colours the diver remembered.
/// `EquipmentRepository` exposes it through a one-line delegate.
class EquipmentColorQueries {
  final AppDatabase _db;

  const EquipmentColorQueries(this._db);

  /// How many gear colours the sheet can use: its Recent row's length.
  static const int cap = recentEquipmentColorRowCap;

  /// The off-palette colours on items [diverId] owns, retired ones included,
  /// newest colour edit first: normalised, each once, at most [cap]. A
  /// colour stored as the diver's own field named "color" is not an item
  /// colour, and a value that is not a code is skipped.
  Future<List<String>> gearColors(String diverId) async {
    final rows = await _db
        .customSelect(
          'SELECT a.value_text AS v FROM equipment_attributes a '
          'JOIN equipment e ON e.id = a.equipment_id '
          'WHERE e.diver_id = ? AND a.attr_key = ? AND a.is_custom = 0 '
          'AND a.value_text IS NOT NULL '
          'ORDER BY a.updated_at DESC, a.id',
          variables: [
            Variable.withString(diverId),
            Variable.withString(EquipmentAttrKeys.color),
          ],
          readsFrom: {_db.equipmentAttributes, _db.equipment},
        )
        .get();
    final seen = <String>{};
    final colors = <String>[];
    for (final row in rows) {
      final code = normalizeEquipmentColor(row.read<String>('v'));
      if (code == null || equipmentColorPalette.contains(code)) continue;
      if (!seen.add(code)) continue;
      colors.add(code);
      if (colors.length == cap) break;
    }
    return colors;
  }
}
