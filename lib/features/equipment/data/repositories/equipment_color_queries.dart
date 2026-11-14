import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
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
  /// newest colour edit first: normalised, each once, at most [cap]. A null
  /// [diverId] (no profile chosen) reads every item, as the equipment list
  /// then shows every item. A colour stored as the diver's own field named
  /// "color" is not an item colour, and a value that is not a code is
  /// skipped.
  Future<List<String>> gearColors(String? diverId) async {
    final rows = await _db
        .customSelect(
          'SELECT a.value_text AS v FROM equipment_attributes a '
          'JOIN equipment e ON e.id = a.equipment_id '
          'WHERE a.attr_key = ? AND a.is_custom = 0 '
          'AND a.value_text IS NOT NULL '
          '${diverId != null ? 'AND e.diver_id = ? ' : ''}'
          'ORDER BY a.updated_at DESC, a.id',
          variables: [
            Variable.withString(EquipmentAttrKeys.color),
            if (diverId != null) Variable.withString(diverId),
          ],
          readsFrom: {_db.equipmentAttributes, _db.equipment},
        )
        .get();
    return distinctCustomEquipmentColors(
      rows.map((row) => row.read<String>('v')),
      cap,
    );
  }
}
