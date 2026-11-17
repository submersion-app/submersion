/// SQL spelling of the lead a dive's detail page shows, for queries that read
/// weight without hydrating `Dive` object graphs.
///
/// Two sources add up, as the buoyancy model adds them (issue #4442):
///
/// - The Weights section. The `dive_weights` rows win whenever the dive has
///   any, and the retired `dives.weight_amount` scalar is never added to
///   them. An older or restored log can still hold the scalar alone: nothing
///   backfills it into rows, the editor only converts a dive when it is
///   opened and saved. A scalar of zero or less is no recorded weight, the
///   same test the detail page and the editor's conversion apply.
/// - Lead carried as gear: every weights item on the dive with no part of its
///   own attached (`GearTree.leafItems`), at the ballast `EquipmentLead`
///   reads from it (dry weight, else negative buoyancy; non-finite values are
///   absent). Weights gear that declares no usable mass adds nothing. A row
///   counts as a part when another row on the dive was attached through it;
///   the one case this reads differently from `GearTree` is a provenance
///   loop, where SQL counts none of the loop's rows and `GearTree` promotes
///   one of them.
///
/// The fragment lives here so Insights, its observations and the query
/// language cannot give two answers for one dive (issue #3914), and
/// `Dive.recordedWeightKg` is its Dart twin, held to it by
/// `dive_weight_sql_parity_test.dart` and
/// `dive_weight_sql_gear_parity_test.dart`. Callers pass the table alias
/// their statement uses for `dives`, and list [recordedWeightTables] among
/// the tables their statement reads.
library;

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';

/// The tables [recordedWeightKgSql] reads besides `dives`, for a stream's
/// `readsFrom` or a query field's `tables`.
const recordedWeightTables = [
  'dive_weights',
  'dive_equipment',
  'equipment',
  'equipment_attributes',
];

/// The largest finite double, so an infinite attribute value (which SQLite
/// stores as a real) reads as absent, as `EquipmentLead.ballastKg` treats it.
const _maxFinite = '1.7976931348623157e308';

/// Lead typed in the Weights section, or NULL when none is recorded.
String _typedKgSql(String alias) =>
    'COALESCE((SELECT SUM(w.amount_kg) FROM dive_weights w '
    'WHERE w.dive_id = $alias.id), '
    'CASE WHEN $alias.weight_amount > 0 THEN $alias.weight_amount END)';

/// Lead carried as weights gear, or NULL when no item declares any.
String _gearKgSql(String alias) =>
    '(SELECT SUM(CASE '
    'WHEN gdw.value_num > 0 AND gdw.value_num <= $_maxFinite '
    'THEN gdw.value_num '
    'WHEN gb.value_num < 0 AND gb.value_num >= -$_maxFinite '
    'THEN -gb.value_num END) '
    'FROM dive_equipment gde '
    'JOIN equipment ge ON ge.id = gde.equipment_id '
    "AND ge.type = '${EquipmentType.weights.name}' "
    'LEFT JOIN equipment_attributes gdw ON gdw.equipment_id = ge.id '
    "AND gdw.attr_key = '${EquipmentAttrKeys.dryWeightKg}' "
    'AND gdw.is_custom = 0 '
    'LEFT JOIN equipment_attributes gb ON gb.equipment_id = ge.id '
    "AND gb.attr_key = '${EquipmentAttrKeys.buoyancyKg}' "
    'AND gb.is_custom = 0 '
    'WHERE gde.dive_id = $alias.id '
    'AND NOT EXISTS (SELECT 1 FROM dive_equipment gpart '
    'WHERE gpart.dive_id = gde.dive_id '
    'AND gpart.via_equipment_id = gde.equipment_id '
    'AND gpart.equipment_id <> gde.equipment_id))';

/// The dive's total lead in kilograms, or NULL when it has none recorded.
///
/// Each source is worked out once, in a derived table, and summed; NULL only
/// when neither has anything.
String recordedWeightKgSql(String alias) =>
    '(SELECT CASE WHEN rw.typed IS NULL AND rw.gear IS NULL THEN NULL '
    'ELSE IFNULL(rw.typed, 0) + IFNULL(rw.gear, 0) END '
    'FROM (SELECT ${_typedKgSql(alias)} AS typed, '
    '${_gearKgSql(alias)} AS gear) rw)';
