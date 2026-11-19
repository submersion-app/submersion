import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_location_move_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/domain/services/location_status_offer.dart';

/// A move asked about but not yet written (issue #4527, phase 3): the
/// items and their status when picked, when and why they move, and the
/// diver's answers to the parts and status questions. Written at a buddy
/// page's Save ([EquipmentMoveFlow.write]).
class EquipmentMovePlan {
  const EquipmentMovePlan({
    required this.items,
    required this.movedAt,
    this.note = '',
    this.withParts = false,
    this.partIds = const {},
    this.status,
  });

  /// The items picked, by id, with their status then.
  final Map<String, EquipmentStatus> items;
  final DateTime movedAt;
  final String note;

  /// Whether their parts go too.
  final bool withParts;

  /// The parts when the diver agreed, for showing the move before it is
  /// written; [EquipmentMoveFlow.write] finds them again from what is
  /// stored then.
  final Set<String> partIds;

  /// The status the diver agreed to, or null to keep each one's.
  final EquipmentStatus? status;
}

/// Moves gear to a place and runs the two follow-up prompts: whether the
/// items' parts go too, then whether to change their status. The prompts
/// and the status write are injected, so this runs the same under a widget
/// and in a unit test.
class EquipmentMoveFlow {
  const EquipmentMoveFlow({
    required this.moves,
    required this.askMoveParts,
    required this.askStatus,
    required this.setStatus,
    this.onStatusFailed,
  });

  final EquipmentLocationMoveRepository moves;

  /// Asked only when the items have parts not already selected.
  final Future<bool> Function(int partCount) askMoveParts;

  /// Asked only when at least one moved item is eligible for the status.
  final Future<bool> Function(EquipmentStatus status, int itemCount) askStatus;

  final Future<void> Function(List<String> ids, EquipmentStatus status)
  setStatus;

  /// Told when the status write fails. The moves are already recorded by
  /// then, so the move itself still succeeded and is not reported failed.
  final void Function()? onStatusFailed;

  /// Moves [items] (and their parts, if the diver agrees) to [target], null
  /// for "No location". Returns how many items moved, parts included.
  Future<int> run({
    required List<EquipmentItem> items,
    required EquipmentLocation? target,
    required DateTime movedAt,
    String note = '',
  }) async {
    if (items.isEmpty) return 0;
    final statuses = {for (final i in items) i.id: i.status};
    final parts = await moves.partsOf(statuses.keys);
    if (parts.isNotEmpty && await askMoveParts(parts.length)) {
      statuses.addAll(parts);
    }
    await moves.recordMoves(
      equipmentIds: statuses.keys,
      locationId: target?.id,
      movedAt: movedAt,
      note: note,
    );
    final (:offered, :eligible) = _offer(target?.kind, statuses);
    if (offered != null && await askStatus(offered, eligible.length)) {
      try {
        await setStatus(eligible, offered);
      } catch (_) {
        onStatusFailed?.call();
      }
    }
    return statuses.length;
  }

  /// The status a move to a place of [kind] offers, and the items of
  /// [statuses] it is offered for. For one kind of place every eligible
  /// item is offered the same status, so the first one found names it.
  static ({EquipmentStatus? offered, List<String> eligible}) _offer(
    EquipmentLocationKind? kind,
    Map<String, EquipmentStatus> statuses,
  ) {
    EquipmentStatus? offered;
    final eligible = <String>[];
    for (final entry in statuses.entries) {
      final status = offeredStatusAfterMove(kind, entry.value);
      if (status == null) continue;
      offered ??= status;
      eligible.add(entry.key);
    }
    return (offered: offered, eligible: eligible);
  }

  /// Asks the parts and status questions for moving [items] to a place of
  /// [targetKind] (null for No location), and writes nothing: the answers
  /// are written later by [write] (issue #4527, phase 3).
  Future<EquipmentMovePlan> plan({
    required List<EquipmentItem> items,
    required EquipmentLocationKind? targetKind,
    required DateTime movedAt,
    String note = '',
  }) async {
    final picked = {for (final i in items) i.id: i.status};
    final parts = await moves.partsOf(picked.keys);
    final withParts = parts.isNotEmpty && await askMoveParts(parts.length);
    final (:offered, :eligible) = _offer(targetKind, {
      ...picked,
      if (withParts) ...parts,
    });
    final agreed = offered != null && await askStatus(offered, eligible.length);
    return EquipmentMovePlan(
      items: picked,
      movedAt: movedAt,
      note: note,
      withParts: withParts,
      partIds: withParts ? parts.keys.toSet() : const {},
      status: agreed ? offered : null,
    );
  }

  /// Writes [plan] to [target] (null for No location): the parts are found
  /// again, so a part installed or removed meanwhile follows the answer as
  /// stored now, and the status the diver agreed to is set on the items it
  /// is still offered for. Asks nothing. A failed status write is not
  /// swallowed: inside a sitting the whole Save rolls back. Returns how
  /// many items moved, parts included.
  Future<int> write(
    EquipmentMovePlan plan, {
    required EquipmentLocation? target,
  }) async {
    if (plan.items.isEmpty) return 0;
    final statuses = {...plan.items};
    if (plan.withParts) statuses.addAll(await moves.partsOf(plan.items.keys));
    await moves.recordMoves(
      equipmentIds: statuses.keys,
      locationId: target?.id,
      movedAt: plan.movedAt,
      note: plan.note,
    );
    final status = plan.status;
    if (status != null) {
      final (:offered, :eligible) = _offer(target?.kind, statuses);
      if (offered == status && eligible.isNotEmpty) {
        await setStatus(eligible, status);
      }
    }
    return statuses.length;
  }
}
