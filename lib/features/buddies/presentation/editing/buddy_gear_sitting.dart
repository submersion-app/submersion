import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/editing/buddy_card_ids.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_location_move_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_location_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/services/equipment_move_flow.dart';
import 'package:submersion/features/equipment/data/services/equipment_return_flow.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/domain/services/gear_with_buddy.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_location_picker_sheet.dart';
import 'package:submersion/features/equipment/presentation/widgets/lend_gear_flow.dart';
import 'package:submersion/features/equipment/presentation/widgets/return_equipment_sheet.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// Gear lent to and returned from a buddy on its page, held in its sitting
/// (issue #4527, phase 3): the questions are asked when the diver acts, and
/// the moves are written at Save, in the order made, in the sitting's one
/// History entry. A Cancel moves nothing and creates no place.

/// One held move: a lend or a return.
class HeldGearMove {
  const HeldGearMove.lend(HeldLend this.lend) : returned = null;
  const HeldGearMove.returned(HeldReturn this.returned) : lend = null;

  final HeldLend? lend;
  final HeldReturn? returned;
}

const String _movesNote = 'buddy.gearMoves';
const String _key = 'buddy.gear';

/// The moves [session] holds, in the order made.
List<HeldGearMove> heldBuddyGearMoves(EditSession<Buddy> session) =>
    session.isDisposed
    ? const []
    : session.recall<List<HeldGearMove>>(_movesNote) ?? const [];

/// Holds [lend], to be written after the moves already held.
void holdBuddyLend(EditSession<Buddy> session, HeldLend lend) =>
    _set(session, [...heldBuddyGearMoves(session), HeldGearMove.lend(lend)]);

/// Holds [returned], to be written after the moves already held.
void holdBuddyReturn(EditSession<Buddy> session, HeldReturn returned) => _set(
  session,
  [...heldBuddyGearMoves(session), HeldGearMove.returned(returned)],
);

/// Drops the held move at [index]; with none left there is no change.
void releaseBuddyGearMove(EditSession<Buddy> session, int index) {
  final moves = [...heldBuddyGearMoves(session)];
  if (index < 0 || index >= moves.length) return;
  moves.removeAt(index);
  _set(session, moves);
}

/// Takes item [itemId] out of the held lend at [index], keeping the rest of
/// it: its parts, when they go too, are found again for what is left
/// ([partsOf]), so the removed item's own stay. Its last item takes the
/// whole lend back. A part is not taken out alone: it follows its item.
Future<void> releaseBuddyLendItem(
  EditSession<Buddy> session,
  int index,
  String itemId, {
  required Future<Map<String, EquipmentStatus>> Function(Iterable<String> ids)
  partsOf,
}) async {
  final moves = heldBuddyGearMoves(session);
  if (index < 0 || index >= moves.length) return;
  final lend = moves[index].lend;
  if (lend == null || !lend.items.any((i) => i.id == itemId)) return;
  final items = [
    for (final item in lend.items)
      if (item.id != itemId) item,
  ];
  if (items.isEmpty) return releaseBuddyGearMove(session, index);
  final plan = lend.plan;
  final kept = {
    for (final entry in plan.items.entries)
      if (entry.key != itemId) entry.key: entry.value,
  };
  final partIds = plan.withParts
      ? plan.partIds.intersection((await partsOf(kept.keys)).keys.toSet())
      : plan.partIds;
  // Read again: the sitting may have ended, or its moves changed, while the
  // parts were read.
  final now = heldBuddyGearMoves(session);
  if (index >= now.length || !identical(now[index].lend, lend)) return;
  _set(session, [
    for (var i = 0; i < now.length; i++)
      i == index
          ? HeldGearMove.lend(
              HeldLend(
                items: items,
                pick: lend.pick,
                plan: EquipmentMovePlan(
                  items: kept,
                  movedAt: plan.movedAt,
                  note: plan.note,
                  withParts: plan.withParts,
                  partIds: partIds,
                  status: plan.status,
                ),
                diverId: lend.diverId,
              ),
            )
          : now[i],
  ]);
}

void _set(EditSession<Buddy> session, List<HeldGearMove> moves) {
  if (session.isDisposed || session.isFrozen) return;
  // Kept before the held change notifies, so what it redraws reads it.
  session.remember(_movesNote, List<HeldGearMove>.unmodifiable(moves));
  if (moves.isEmpty) {
    session.releaseWrite(_key);
    return;
  }
  session.holdChange(
    _key,
    cardId: BuddyCardId.gear.name,
    write: () => writeBuddyGearMoves(
      heldBuddyGearMoves(session),
      buddy: session.working,
    ),
  );
}

/// Writes [moves] in order, inside the sitting's transaction: a lend finds
/// or creates the buddy's place first, then moves the gear as the diver
/// answered; a return sends each item back to where it was before the
/// loan, worked out from what is stored now.
///
/// A place made for [buddy] takes the name the sitting gives them, which a
/// rename in the same sitting may have changed since the lend was held.
Future<void> writeBuddyGearMoves(
  List<HeldGearMove> moves, {
  Buddy? buddy,
}) async {
  final locations = EquipmentLocationRepository();
  final moveRepository = EquipmentLocationMoveRepository();
  final setStatus = EquipmentRepository().setStatusForMany;
  Future<bool> never(Object? _, [Object? _]) async => false;
  for (final move in moves) {
    if (move.lend case final lend?) {
      final target = switch (lend.pick) {
        PlacePick(:final location) => location,
        NoLocationPick() => null,
        BuddyPick(buddy: final pick) => await locations.findOrCreateForBuddy(
          diverId: lend.diverId,
          buddyId: pick.id,
          name: pick.id == buddy?.id ? buddy!.name : pick.name,
        ),
      };
      await EquipmentMoveFlow(
        moves: moveRepository,
        askMoveParts: never,
        askStatus: never,
        setStatus: setStatus,
      ).write(lend.plan, target: target);
    }
    if (move.returned case final returned?) {
      final places = {for (final l in await locations.getLocations()) l.id: l};
      await EquipmentReturnFlow(
        moves: moveRepository,
        askMoveParts: never,
        askStatus: never,
        setStatus: setStatus,
      ).write(returned.plan, places: places);
    }
  }
}

/// One row of the buddy's Gear card in a sitting: the gear, the place it is
/// at or goes to, and the held move that brought it there (null for gear
/// they had already).
typedef BuddyGearRow = ({GearWithBuddy gear, int? heldIndex});

/// The buddy's gear as [session] holds it: [stored], less what a held move
/// returns, plus what a held move lends to this buddy (at a place standing
/// for theirs, which is made at Save), with the parts the diver agreed to
/// send along, found by id in [items].
List<BuddyGearRow> buddyGearInSitting(
  EditSession<Buddy> session,
  List<GearWithBuddy> stored, {
  List<EquipmentItem> items = const [],
}) {
  final byId = {for (final item in items) item.id: item};
  final moves = heldBuddyGearMoves(session);
  final buddy = session.working;
  var rows = <BuddyGearRow>[
    for (final gear in stored) (gear: gear, heldIndex: null),
  ];
  for (var i = 0; i < moves.length; i++) {
    final move = moves[i];
    if (move.returned case final returned?) {
      // The parts the diver agreed to return go with their items.
      final ids = {...returned.plan.items.keys, ...returned.plan.partIds};
      rows = [
        for (final row in rows)
          if (!ids.contains(row.gear.item.id)) row,
      ];
    }
    if (move.lend case final lend?) {
      final pick = lend.pick;
      final here = pick is BuddyPick && pick.buddy.id == buddy.id;
      final lent = [
        ...lend.items,
        for (final id in lend.plan.partIds) ?byId[id],
      ];
      final ids = {for (final item in lent) item.id};
      rows = [
        for (final row in rows)
          if (!ids.contains(row.gear.item.id)) row,
        if (here)
          for (final item in lent)
            (gear: (item: item, place: _heldPlace(buddy, lend)), heldIndex: i),
      ];
    }
  }
  return rows;
}

/// The place standing for [buddy]'s until Save makes it.
EquipmentLocation _heldPlace(Buddy buddy, HeldLend lend) => EquipmentLocation(
  id: '',
  name: buddy.name,
  kind: EquipmentLocationKind.person,
  buddyId: buddy.id,
  createdAt: lend.plan.movedAt,
  updatedAt: lend.plan.movedAt,
);
