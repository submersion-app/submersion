import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';
import 'package:submersion/features/trips/presentation/editing/trip_gear_sitting.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/sitting_list.dart';

/// What the cylinder board's sheets hand a trip's sitting instead of
/// writing (issue #4527, phase 3): fills, adjustments, slot edits, deletes
/// and the board's order, held in [session] through [board] until Save.
class TripBoardHold {
  TripBoardHold({required this.session, required this.board});

  final EditSession<Trip> session;
  final SittingList<Trip, TripCylindersHeld> board;

  TripCylindersHeld get _held =>
      heldCylindersOf(session, board) ?? const TripCylindersHeld();

  void _set(TripCylindersHeld next) => board.set(session, [next]);

  /// New fills (no id) or an edited one, each copied to its cylinder's
  /// passport at Save with [note].
  Future<void> fills(
    List<TripCylinderEvent> fills,
    TripFillCopyNote note,
  ) async => _set(_held.withEvents(fills, note: note));

  /// A new adjustment (no id) or an edited one.
  Future<void> adjustment(TripCylinderEvent event) async =>
      _set(_held.withEvents([event]));

  Future<void> editSlot(TripCylinder slot) async =>
      _set(_held.withSlotEdited(slot));

  Future<void> deleteSlot(String id) async => _set(_held.withoutSlot(id));

  Future<void> deleteEvent(String id) async => _set(_held.withoutEvent(id));

  Future<void> reorder(List<String> orderedIds) async =>
      _set(_held.withSlotsReordered(orderedIds));

  /// New slots with the orders they carry.
  Future<void> addSlots(List<TripCylinder> drafts) async =>
      _set(_held.withSlotsAdded(drafts));

  /// Whether slot [id] is stored, not only made in this sitting: a dive can
  /// be linked only to a stored slot.
  bool isStored(String id) =>
      board.loaded(session)?.singleOrNull?.slots.any((s) => s.id == id) ??
      false;
}
