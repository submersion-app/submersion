import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_location_move_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/domain/services/gear_with_buddy.dart';

/// Takes gear back from a buddy (issue #3790): each item goes to where it was
/// before the loan, then whatever was Loaned Out is offered Active once. This
/// sits beside the move flow because a return has no single target, and its
/// offer does not depend on the kind of place: gear back from a loan is back,
/// even if it goes to a shop. The prompts and the status write are injected,
/// so this runs the same under a widget and in a unit test.
class EquipmentReturnFlow {
  const EquipmentReturnFlow({
    required this.moves,
    required this.askMoveParts,
    required this.askStatus,
    required this.setStatus,
    this.onStatusFailed,
  });

  final EquipmentLocationMoveRepository moves;

  /// Asked only when the items have parts with the same buddy.
  final Future<bool> Function(int partCount) askMoveParts;

  /// Asked only when at least one returned item is Loaned Out.
  final Future<bool> Function(EquipmentStatus status, int itemCount) askStatus;

  final Future<void> Function(List<String> ids, EquipmentStatus status)
  setStatus;

  /// Told when the status write fails. The moves are already recorded by
  /// then, so the return itself still succeeded and is not reported failed.
  final void Function()? onStatusFailed;

  /// Where [items] would go. Null stands for No location.
  Future<Set<EquipmentLocation?>> destinations({
    required List<EquipmentItem> items,
    required String buddyId,
    required Map<String, EquipmentLocation> places,
  }) async => {
    for (final item in items)
      placeBeforeLoan(await moves.getMovesFor(item.id), places, buddyId),
  };

  /// Returns [items] (and their parts with this buddy, if the diver agrees).
  /// Returns how many items moved, parts included. A time before an item's
  /// current move is held at that move, or the item would stay with the buddy.
  Future<int> run({
    required List<EquipmentItem> items,
    required String buddyId,
    required Map<String, EquipmentLocation> places,
    required DateTime movedAt,
    String note = '',
  }) async {
    if (items.isEmpty) return 0;
    final statuses = {for (final i in items) i.id: i.status};
    final parts = await _partsWithBuddy(statuses.keys, buddyId, places);
    if (parts.isNotEmpty && await askMoveParts(parts.length)) {
      statuses.addAll(parts);
    }
    final groups = <(String?, DateTime), List<String>>{};
    for (final id in statuses.keys) {
      final history = await moves.getMovesFor(id);
      final target = placeBeforeLoan(history, places, buddyId);
      final at = history.isEmpty
          ? movedAt
          : notBeforeCurrentMove(movedAt, history.first.movedAt);
      groups.putIfAbsent((target?.id, at), () => []).add(id);
    }
    // All or nothing, so no item comes back without its status prompt.
    await moves.recordMoveGroups([
      for (final MapEntry(key: (locationId, at), value: ids) in groups.entries)
        (equipmentIds: ids, locationId: locationId, movedAt: at),
    ], note: note);
    final loaned = [
      for (final entry in statuses.entries)
        if (entry.value == EquipmentStatus.loaned) entry.key,
    ];
    if (loaned.isNotEmpty &&
        await askStatus(EquipmentStatus.active, loaned.length)) {
      try {
        await setStatus(loaned, EquipmentStatus.active);
      } catch (_) {
        onStatusFailed?.call();
      }
    }
    return statuses.length;
  }

  Future<Map<String, EquipmentStatus>> _partsWithBuddy(
    Iterable<String> ids,
    String buddyId,
    Map<String, EquipmentLocation> places,
  ) async {
    final parts = await moves.partsOf(ids);
    if (parts.isEmpty) return parts;
    final current = await moves.getCurrentLocationIds();
    return {
      for (final entry in parts.entries)
        if (places[current[entry.key]]?.buddyId == buddyId)
          entry.key: entry.value,
    };
  }
}
