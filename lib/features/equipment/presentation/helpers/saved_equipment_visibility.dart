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
Future<EquipmentFilterState?> viewRevealingSavedEquipment({
  required QueryIdSetRunner runner,
  required EquipmentFilterState filter,
  required String? diverId,
  required String equipmentId,
  required EquipmentStatus status,
}) async {
  Future<bool> shows(EquipmentFilterState view) async {
    final ids = await runner.ids(
      compileEquipmentFilter(view, diverId: diverId),
      scope: view.ownerScope(diverId),
    );
    return ids.contains(equipmentId);
  }

  if (await shows(filter)) return null;
  const defaultView = EquipmentFilterState();
  if (await shows(defaultView)) return defaultView;
  return EquipmentFilterState(status: status);
}
