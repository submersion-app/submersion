import 'package:flutter/foundation.dart';

import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_card_ids.dart';
import 'package:submersion/features/trips/data/repositories/trip_equipment_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/trip_equipment_providers.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_sitting_refusal.dart';
import 'package:submersion/shared/widgets/record_editing/sitting_list.dart';

/// The held change of a passport's Tag card (issue #4527, phase 3): an
/// existing tag linked to the item, written at Save, which releases the
/// tag from an item no longer in service and re-keys the cylinder's fills.
const String gearPassportTagKey = 'equipment.passportTag';

const String _tagNoteKey = 'equipment.passportTag.id';

/// The passport id the sitting gives the item: the linked tag's, or
/// [stored] when none is held.
String? passportIdInSitting(
  EditSession<EquipmentItem> session,
  String? stored,
) => session.recall<String>(_tagNoteKey) ?? stored;

/// Whether the sitting links a tag.
bool holdsPassportTag(EditSession<EquipmentItem> session) =>
    session.isHeld(gearPassportTagKey);

/// Links the tag [passportId] in the sitting. Back to [stored], the item's
/// own id, it is no change.
void holdPassportTag(
  EditSession<EquipmentItem> session,
  String passportId, {
  required String? stored,
  required CylinderPassportRepository repository,
  String? diverId,
}) {
  if (session.isDisposed || session.isFrozen) return;
  if (passportId == stored) {
    session.remember(_tagNoteKey, null);
    session.releaseWrite(gearPassportTagKey);
    return;
  }
  session.remember(_tagNoteKey, passportId);
  session.holdChange(
    gearPassportTagKey,
    cardId: GearItemCardId.passportTag.name,
    write: () async {
      try {
        await repository.assignPassportId(
          equipmentId: session.stored.id,
          passportId: passportId,
          diverId: diverId,
        );
      } on PassportIdInUse catch (e) {
        final holder = await EquipmentRepository().getEquipmentById(
          e.equipmentId,
        );
        final name = holder?.name ?? e.equipmentId;
        throw RecordSittingRefusal((l) => l.passport_tag_linkInUse(name));
      }
    },
  );
}

/// The item's packed trips and bag choices, held until the passport is saved.
final gearItemTripsList = SittingList<EquipmentItem, EquipmentPacking>(
  key: 'equipment.trips',
  cardId: GearItemCardId.passportTrip.name,
  read: (item) => TripEquipmentRepository().packingForEquipment(item.id),
  write: (item, loaded, current) async {
    final repository = TripEquipmentRepository();
    final before = {for (final row in loaded) row.tripId: row.bagId};
    final after = {for (final row in current) row.tripId: row.bagId};
    for (final row in after.entries) {
      if (!before.containsKey(row.key)) {
        if (row.value case final bagId?) {
          await repository.packInBag(row.key, item.id, bagId);
        } else {
          await repository.pack(row.key, [item.id]);
        }
      } else if (before[row.key] != row.value) {
        await repository.assignBag(row.key, item.id, row.value, orLoose: true);
      }
    }
    for (final tripId in before.keys) {
      if (!after.containsKey(tripId)) await repository.unpack(tripId, item.id);
    }
    return null;
  },
  same: (a, b) => setEquals(a.toSet(), b.toSet()),
);

/// [stored], the item's trips as the passport shows them, with the
/// sitting's packing laid over it: a trip unpacked in the sitting stays only
/// as a slot on its cylinder board, and one packed in it is added from
/// [trips], every trip.
List<PackedTrip> packedTripsInSitting(
  EditSession<EquipmentItem> session,
  List<PackedTrip> stored,
  List<Trip> trips,
) {
  final packed = gearItemTripsList.current(session);
  if (packed == null || !gearItemTripsList.isChanged(session)) return stored;
  final ids = {for (final row in packed) row.tripId};
  final shown = {for (final p in stored) p.trip.id};
  return rankPackedTrips([
    for (final p in stored)
      if (ids.contains(p.trip.id) || p.slot)
        PackedTrip(trip: p.trip, packed: ids.contains(p.trip.id), slot: p.slot),
    for (final trip in trips)
      if (ids.contains(trip.id) && !shown.contains(trip.id))
        PackedTrip(trip: trip, packed: true, slot: false),
  ], DateTime.now());
}

/// Packs the item for [tripId] in the sitting, optionally into [bagId].
void packForTripInSitting(
  EditSession<EquipmentItem> session,
  String tripId, {
  String? bagId,
}) {
  final current = gearItemTripsList.current(session);
  if (current == null || current.any((row) => row.tripId == tripId)) return;
  gearItemTripsList.set(session, [...current, (tripId: tripId, bagId: bagId)]);
}

/// Unpacks the item from [tripId] in the sitting.
void unpackFromTripInSitting(
  EditSession<EquipmentItem> session,
  String tripId,
) {
  final current = gearItemTripsList.current(session);
  if (current == null) return;
  gearItemTripsList.set(session, [
    for (final row in current)
      if (row.tripId != tripId) row,
  ]);
}
