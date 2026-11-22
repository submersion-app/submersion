import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_location_move_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/domain/services/gear_with_buddy.dart';

/// A return asked about but not yet written (issue #4527, phase 3): the
/// items and their status when picked, when and why, and the diver's
/// answers to the parts and status questions. Written at a buddy page's
/// Save ([EquipmentReturnFlow.write]).
class EquipmentReturnPlan {
  const EquipmentReturnPlan({
    required this.items,
    required this.buddyId,
    required this.movedAt,
    this.note = '',
    this.withParts = false,
    this.partIds = const {},
    this.setActive = false,
  });

  /// The items picked, by id, with their status then.
  final Map<String, EquipmentStatus> items;
  final String buddyId;
  final DateTime movedAt;
  final String note;

  /// Whether their parts with the buddy come back too.
  final bool withParts;

  /// The parts with the buddy when the diver agreed, for showing the
  /// return before it is written; [EquipmentReturnFlow.write] finds them
  /// again from what is stored then.
  final Set<String> partIds;

  /// Whether what was Loaned Out goes back to Active.
  final bool setActive;
}

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
  });

  final EquipmentLocationMoveRepository moves;

  /// Asked only when the items have parts with the same buddy.
  final Future<bool> Function(int partCount) askMoveParts;

  /// Asked only when at least one returned item is Loaned Out.
  final Future<bool> Function(EquipmentStatus status, int itemCount) askStatus;

  final Future<void> Function(List<String> ids, EquipmentStatus status)
  setStatus;

  /// Where [items] would go. Null stands for No location.
  Future<Set<EquipmentLocation?>> destinations({
    required List<EquipmentItem> items,
    required String buddyId,
    required Map<String, EquipmentLocation> places,
  }) async => {
    for (final item in items)
      placeBeforeLoan(await moves.getMovesFor(item.id), places, buddyId),
  };

  /// The ids of [statuses] that are Loaned Out.
  static List<String> _loaned(Map<String, EquipmentStatus> statuses) => [
    for (final entry in statuses.entries)
      if (entry.value == EquipmentStatus.loaned) entry.key,
  ];

  /// Moves [ids] each back to where it was before the loan, items sharing a
  /// destination and time in one write. All or nothing, so no item comes
  /// back without its status prompt.
  Future<void> _recordReturn(
    Iterable<String> ids,
    String buddyId,
    Map<String, EquipmentLocation> places,
    DateTime movedAt,
    String note,
  ) async {
    final groups = <(String?, DateTime), List<String>>{};
    for (final id in ids) {
      final history = await moves.getMovesFor(id);
      final target = placeBeforeLoan(history, places, buddyId);
      final at = history.isEmpty
          ? movedAt
          : notBeforeCurrentMove(movedAt, history.first.movedAt);
      groups.putIfAbsent((target?.id, at), () => []).add(id);
    }
    await moves.recordMoveGroups([
      for (final MapEntry(key: (locationId, at), value: ids) in groups.entries)
        (equipmentIds: ids, locationId: locationId, movedAt: at),
    ], note: note);
  }

  /// Asks the parts and status questions for returning [items] from
  /// [buddyId], and writes nothing: the answers are written later by
  /// [write] (issue #4527, phase 3).
  Future<EquipmentReturnPlan> plan({
    required List<EquipmentItem> items,
    required String buddyId,
    required Map<String, EquipmentLocation> places,
    required DateTime movedAt,
    String note = '',
  }) async {
    final picked = {for (final i in items) i.id: i.status};
    final parts = await _partsWithBuddy(picked.keys, buddyId, places);
    final withParts = parts.isNotEmpty && await askMoveParts(parts.length);
    final loaned = _loaned({...picked, if (withParts) ...parts});
    final setActive =
        loaned.isNotEmpty &&
        await askStatus(EquipmentStatus.active, loaned.length);
    return EquipmentReturnPlan(
      items: picked,
      buddyId: buddyId,
      movedAt: movedAt,
      note: note,
      withParts: withParts,
      partIds: withParts ? parts.keys.toSet() : const {},
      setActive: setActive,
    );
  }

  /// Writes [plan]: each item, and its parts still with the buddy when the
  /// diver agreed, goes back to where it was before the loan, worked out
  /// again from what is stored now; Loaned Out goes back to Active when the
  /// diver agreed. Asks nothing, and a failed status write is not
  /// swallowed. Returns how many items moved, parts included.
  Future<int> write(
    EquipmentReturnPlan plan, {
    required Map<String, EquipmentLocation> places,
  }) async {
    if (plan.items.isEmpty) return 0;
    final statuses = {...plan.items};
    if (plan.withParts) {
      statuses.addAll(
        await _partsWithBuddy(plan.items.keys, plan.buddyId, places),
      );
    }
    await _recordReturn(
      statuses.keys,
      plan.buddyId,
      places,
      plan.movedAt,
      plan.note,
    );
    final loaned = _loaned(statuses);
    if (plan.setActive && loaned.isNotEmpty) {
      await setStatus(loaned, EquipmentStatus.active);
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
