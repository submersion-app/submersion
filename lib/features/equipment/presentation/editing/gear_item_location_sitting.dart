import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_location_move_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_location_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/services/equipment_move_flow.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location_move.dart';
import 'package:submersion/features/equipment/domain/services/location_status_offer.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_card_ids.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_edit_fields.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_row_writes.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_location_picker_sheet.dart';
import 'package:submersion/features/equipment/presentation/widgets/move_equipment_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/sitting_list.dart';

/// A move of the gear item asked about in its page's sitting (issue #4527,
/// phase 3, plan 6), held until Save: where it goes ([pick]), the answers
/// to the parts and status questions ([plan]), and the diver a place made
/// for a buddy is filed under. A buddy's place is found or created at
/// Save, so a Cancel leaves no place behind.
class HeldGearItemMove {
  const HeldGearItemMove({
    required this.pick,
    required this.plan,
    this.diverId,
  });

  final LocationPick pick;
  final EquipmentMovePlan plan;
  final String? diverId;
}

const String _moveKey = 'equipment.move';
const String _moveNote = 'equipment.move.held';
const String _statusNote = 'equipment.move.setStatus';

/// The status a held move set on the item ([set]), and the one it had
/// before ([before]).
typedef _MoveStatus = ({EquipmentStatus before, EquipmentStatus set});

/// The item's past moves, edited and deleted in its sitting, written at
/// Save. Only those the diver changed are written.
final gearItemMovesList = SittingList<EquipmentItem, EquipmentLocationMove>(
  key: 'equipment.moveHistory',
  cardId: GearItemCardId.location.name,
  read: (item) => EquipmentLocationMoveRepository().getMovesFor(item.id),
  // Past moves are only edited and deleted here: a move is made by the
  // move flow ([holdGearItemMove]).
  write: (item, loaded, current) {
    final repository = EquipmentLocationMoveRepository();
    return writeRowChanges(
      loaded: loaded,
      current: current,
      idOf: (m) => m.id,
      update: repository.updateMove,
      delete: repository.deleteMove,
    );
  },
);

/// Moves [item] in its page's sitting: the move sheet, then the parts and
/// status questions, all asked now, with nothing written. Null when the
/// diver backs out or the parts cannot be read (a SnackBar says so).
Future<HeldGearItemMove?> planGearItemMove(
  BuildContext context,
  WidgetRef ref,
  EquipmentItem item,
) async {
  // Handled now, though awaited only at the end: a failure while the diver
  // is still choosing would otherwise go unhandled. A buddy's place is then
  // filed under no diver.
  final diverIdFuture = ref
      .read(validatedCurrentDiverIdProvider.future)
      .then<String?>((id) => id, onError: (Object _) => null);
  final moves = ref.read(equipmentLocationMoveRepositoryProvider);
  final draft = await showMoveEquipmentSheet(context, ref, itemCount: 1);
  if (draft == null || !context.mounted) return null;
  final messenger = ScaffoldMessenger.of(context);
  final failed = context.l10n.common_error_tryAgain;
  final flow = EquipmentMoveFlow(
    moves: moves,
    askMoveParts: (n) => askMoveParts(context, n),
    askStatus: (status, n) => askMoveStatus(context, status, n),
    // Nothing is written now: the status is set at Save.
    setStatus: (_, _) async {},
  );
  final EquipmentMovePlan plan;
  try {
    plan = await flow.plan(
      items: [item],
      targetKind: targetKindOf(draft.pick),
      movedAt: draft.movedAt,
      note: draft.note,
    );
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(failed)));
    return null;
  }
  return HeldGearItemMove(
    pick: draft.pick,
    plan: plan,
    diverId: await diverIdFuture,
  );
}

/// The kind of place [pick] is: a buddy's is a person's.
EquipmentLocationKind? targetKindOf(LocationPick pick) => switch (pick) {
  PlacePick(:final location) => location.kind,
  NoLocationPick() => null,
  BuddyPick() => EquipmentLocationKind.person,
};

/// The move the sitting holds, or null.
HeldGearItemMove? heldGearItemMove(EditSession<EquipmentItem> session) =>
    session.isDisposed ? null : session.recall<HeldGearItemMove>(_moveNote);

/// Holds [move] in the item's sitting, in place of one held before. The
/// status the diver agreed to for the item itself is its status in the
/// sitting, shown on Details; the parts' is written with the move.
void holdGearItemMove(
  EditSession<EquipmentItem> session,
  HeldGearItemMove move,
) {
  if (session.isDisposed || session.isFrozen) return;
  final item = session.stored;
  final now = session.valueOf(gearStatusField);
  // The status a move held before set, and what the item had before it:
  // taken back only while the diver has not changed it since.
  final previous = session.recall<_MoveStatus>(_statusNote);
  final ours = previous != null && previous.set == now;
  final before = ours ? previous.before : now;
  final status = move.plan.status;
  final forItem =
      status != null &&
      offeredStatusAfterMove(
            targetKindOf(move.pick),
            move.plan.items[item.id] ?? now,
          ) ==
          status;
  if (forItem) {
    session.set(gearStatusField, status);
  } else if (ours) {
    // A move held before set the item's status; this one does not.
    session.set(gearStatusField, before);
  }
  session
    ..remember(_statusNote, forItem ? (before: before, set: status) : null)
    ..remember(_moveNote, move)
    ..holdChange(
      _moveKey,
      cardId: GearItemCardId.location.name,
      write: () => writeGearItemMove(move, itemId: item.id),
    );
}

/// Writes [move] inside the sitting's transaction: a buddy's place found
/// or created first, then the item and the parts the diver agreed to move,
/// and the status the diver agreed to on the parts. The item's own status
/// is the sitting's, already written with the row.
Future<void> writeGearItemMove(
  HeldGearItemMove move, {
  required String itemId,
}) async {
  final target = switch (move.pick) {
    PlacePick(:final location) => location,
    NoLocationPick() => null,
    BuddyPick(:final buddy) =>
      await EquipmentLocationRepository().findOrCreateForBuddy(
        diverId: move.diverId,
        buddyId: buddy.id,
        name: buddy.name,
      ),
  };
  final items = EquipmentRepository();
  Future<bool> never(Object? _, [Object? _]) async => false;
  await EquipmentMoveFlow(
    moves: EquipmentLocationMoveRepository(),
    askMoveParts: never,
    askStatus: never,
    setStatus: (ids, status) async {
      final parts = [
        for (final id in ids)
          if (id != itemId) id,
      ];
      if (parts.isNotEmpty) await items.setStatusForMany(parts, status);
    },
  ).write(move.plan, target: target);
}
