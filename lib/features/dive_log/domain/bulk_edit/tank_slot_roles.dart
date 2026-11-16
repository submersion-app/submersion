import 'package:submersion/core/constants/app_enums.dart';

/// The role each of one dive's tanks gets from a bulk edit's ordered
/// [slotRoles] (issue #4412): the tank with the lowest `tankOrder` takes the
/// first role, the next the second, and so on. Keyed by tank id.
///
/// Null when the dive does not line up with the positions, so it keeps its
/// roles: no positions, a different number of tanks, or two tanks sharing an
/// order, where which cylinder is "tank 1" would be a guess.
Map<String, TankRole>? slotRolesForDive(
  List<({String id, int order})> tanks,
  List<TankRole> slotRoles,
) {
  if (slotRoles.isEmpty || tanks.length != slotRoles.length) return null;
  final sorted = [...tanks]..sort((a, b) => a.order.compareTo(b.order));
  for (var i = 1; i < sorted.length; i++) {
    if (sorted[i].order == sorted[i - 1].order) return null;
  }
  return {for (var i = 0; i < sorted.length; i++) sorted[i].id: slotRoles[i]};
}
