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

/// The trips the item is packed for, by id, as its sitting has them
/// (issue #4527, phase 3): packed and unpacked from a passport's Trip
/// card, written at Save. A trip's packed gear is the trip's, so its
/// History has these rows too.
final gearItemTripsList = SittingList<EquipmentItem, String>(
  key: 'equipment.trips',
  cardId: GearItemCardId.passportTrip.name,
  read: (item) async =>
      (await TripEquipmentRepository().tripIdsForEquipment(item.id)).toList()
        ..sort(),
  write: (item, loaded, current) async {
    final repository = TripEquipmentRepository();
    final before = loaded.toSet();
    final after = current.toSet();
    for (final tripId in after.difference(before)) {
      await repository.pack(tripId, [item.id]);
    }
    for (final tripId in before.difference(after)) {
      await repository.unpack(tripId, item.id);
    }
    return null;
  },
  same: (a, b) => sameIdSets(a, b, (id) => id),
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
  final ids = packed.toSet();
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

/// Packs the item for [tripId] in the sitting.
void packForTripInSitting(EditSession<EquipmentItem> session, String tripId) {
  final current = gearItemTripsList.current(session);
  if (current == null || current.contains(tripId)) return;
  gearItemTripsList.set(session, [...current, tripId]);
}

/// Unpacks the item from [tripId] in the sitting.
void unpackFromTripInSitting(
  EditSession<EquipmentItem> session,
  String tripId,
) {
  final current = gearItemTripsList.current(session);
  if (current == null) return;
  gearItemTripsList.set(session, [
    for (final id in current)
      if (id != tripId) id,
  ]);
}
