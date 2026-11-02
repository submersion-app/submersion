import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location_move.dart';
import 'package:submersion/features/equipment/domain/services/gear_at_dive_center.dart';

/// One item with a buddy, and the place that says so.
typedef GearWithBuddy = ({EquipmentItem item, EquipmentLocation place});

/// The [items] whose current place in [currentPlaces] links to [buddyId], by
/// item name. An archived place counts: the gear is still with them.
List<GearWithBuddy> gearWithBuddy(
  String buddyId,
  List<EquipmentItem> items,
  Map<String, EquipmentLocation> currentPlaces,
) => gearAtPlacesWhere(
  items,
  currentPlaces,
  (place) => place.buddyId == buddyId,
);

/// Where an item was before it went to [buddyId]: the place of the newest of
/// [movesNewestFirst] that is not at one of that buddy's [places]. Null when
/// that is no location, or there is no such move, or the place was archived
/// or removed since, so gear never goes back to somewhere the diver retired.
EquipmentLocation? placeBeforeLoan(
  List<EquipmentLocationMove> movesNewestFirst,
  Map<String, EquipmentLocation> places,
  String buddyId,
) {
  for (final move in movesNewestFirst) {
    final place = places[move.locationId];
    if (place?.buddyId == buddyId) continue;
    return place == null || place.isArchived ? null : place;
  }
  return null;
}

/// [movedAt], held at [currentMoveAt] when it is earlier. An item is wherever
/// its newest move says, so a return logged for the day of a loan must not
/// land before the loan. An equal time still ranks newer, through created_at.
DateTime notBeforeCurrentMove(DateTime movedAt, DateTime currentMoveAt) =>
    movedAt.isBefore(currentMoveAt) ? currentMoveAt : movedAt;
