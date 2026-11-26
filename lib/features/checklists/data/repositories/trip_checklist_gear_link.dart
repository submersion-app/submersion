import 'package:drift/drift.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';

/// When a gear item on a trip checklist follows its gear's packing: while
/// [equipment] is off the wishlist (#2025) and usable by the trip's diver
/// [tripDiverId], by the rule a gear set applies (owned, shared with that
/// diver, ownerless, or a trip with no diver; see isSetMemberUsableBy).
/// Otherwise the item reads and ticks as a plain one by its own is_done, as
/// it does once the equipment is deleted, so it is never stranded unticked
/// with gear the trip cannot pack.
///
/// With a [viewerId], the equipment must be usable by that diver too: on a
/// shared trip a sharee never reads the packing of the owner's gear that
/// is hidden from them (the Gear tab hides it the same way), and sees the
/// row as a plain item instead.
Expression<bool> gearFollowsPacking(
  AppDatabase db,
  $EquipmentTable equipment,
  Expression<String> tripDiverId, {
  String? viewerId,
}) {
  final follows =
      equipment.status.equals(EquipmentStatus.wanted.name).not() &
      _usableBy(db, equipment, tripDiverId);
  return viewerId == null
      ? follows
      : follows & _usableBy(db, equipment, Variable<String>(viewerId));
}

/// Owned by [diverId], shared with them, ownerless, or no diver at all.
Expression<bool> _usableBy(
  AppDatabase db,
  $EquipmentTable equipment,
  Expression<String> diverId,
) {
  final shares = db.equipmentShares;
  return diverId.isNull() |
      equipment.diverId.isNull() |
      equipment.diverId.equalsExp(diverId) |
      existsQuery(
        db.selectOnly(shares)
          ..addColumns([shares.id])
          ..where(
            shares.equipmentId.equalsExp(equipment.id) &
                shares.diverId.equalsExp(diverId),
          ),
      );
}

/// [gearFollowsPacking] as SQL over `equipment e` and `trips t`, for the
/// hand-written progress query.
const gearFollowsPackingSql =
    "e.status <> 'wanted' AND (t.diver_id IS NULL OR e.diver_id IS NULL "
    'OR e.diver_id = t.diver_id OR EXISTS (SELECT 1 FROM equipment_shares s '
    'WHERE s.equipment_id = e.id AND s.diver_id = t.diver_id))';
