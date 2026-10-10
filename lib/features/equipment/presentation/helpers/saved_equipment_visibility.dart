import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/models/equipment_filter_state.dart';
import 'package:submersion/features/equipment/query/equipment_filter_query.dart';
import 'package:submersion/features/query/data/query_id_set_runner.dart';

/// The list view that shows a just-saved item, or null when [filter], the
/// view the list is on, already shows it (#3068).
///
/// The default view leaves out wishlist, retired and sold gear, so saving a
/// Wanted item from it used to look like the save had failed. The check runs
/// the list's own compiled query rather than re-deriving its rules, so it
/// sees every axis (status, category, tags, owner) exactly as the list does.
///
/// The view offered is the default one when that shows the item, else the
/// item's own [status] view.
///
/// [beforeQuery] runs with each query's tables before it does, as the
/// list's `watchQueryIds` does: a service-due view reads a cache the save
/// has just set refreshing, and must see the new verdicts, not the old.
Future<EquipmentFilterState?> viewRevealingSavedEquipment({
  required QueryIdSetRunner runner,
  required EquipmentFilterState filter,
  required String? diverId,
  required String equipmentId,
  required EquipmentStatus status,
  Future<void> Function(Set<String> tablesTouched)? beforeQuery,
}) async {
  Future<bool> shows(EquipmentFilterState view) async {
    final compiled = compileEquipmentFilter(view, diverId: diverId);
    await beforeQuery?.call(compiled.tablesTouched);
    // Narrowed to the one row, so the check never lists the whole view.
    final owner = view.ownerScope(diverId);
    final ids = await runner.ids(
      compiled,
      scope: (
        sql: [
          if (owner != null) owner.sql,
          '${compiled.rootAlias}.${compiled.idColumn} = ?',
        ].join(' AND '),
        params: [...?owner?.params, equipmentId],
      ),
    );
    return ids.contains(equipmentId);
  }

  if (await shows(filter)) return null;
  const defaultView = EquipmentFilterState();
  if (await shows(defaultView)) return defaultView;
  return EquipmentFilterState(status: status);
}
