import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_location_move_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/domain/services/location_status_offer.dart';

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
    // For one kind of place every eligible item is offered the same
    // status, so the first one found names it.
    EquipmentStatus? offered;
    final eligible = <String>[];
    for (final entry in statuses.entries) {
      final status = offeredStatusAfterMove(target?.kind, entry.value);
      if (status == null) continue;
      offered ??= status;
      eligible.add(entry.key);
    }
    if (offered != null && await askStatus(offered, eligible.length)) {
      try {
        await setStatus(eligible, offered);
      } catch (_) {
        onStatusFailed?.call();
      }
    }
    return statuses.length;
  }
}
