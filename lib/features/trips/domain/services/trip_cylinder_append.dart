import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';

/// The slots of [drafts] that join a board holding [board] (each slot's
/// tank and order), in their given order after its last slot, whatever
/// order they carry: a slot for a tank already on the board, or one earlier
/// in [drafts], is left out (#2873). Each takes [tripId], and an id from
/// [newId] when it has none and [newId] is given.
List<TripCylinder> cylindersToAppend(
  Iterable<({String? equipmentId, int sortOrder})> board,
  List<TripCylinder> drafts, {
  required String tripId,
  String Function()? newId,
}) {
  final start =
      board.fold(-1, (end, r) => r.sortOrder > end ? r.sortOrder : end) + 1;
  final onBoard = {for (final r in board) ?r.equipmentId};
  final fresh = [
    for (final (i, c) in drafts.indexed)
      if (c.equipmentId == null ||
          (!onBoard.contains(c.equipmentId) &&
              drafts.indexWhere((o) => o.equipmentId == c.equipmentId) == i))
        c,
  ];
  return [
    for (final (i, c) in fresh.indexed)
      c.copyWith(
        id: c.id.isEmpty && newId != null ? newId() : c.id,
        tripId: tripId,
        sortOrder: start + i,
      ),
  ];
}
