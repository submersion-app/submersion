import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/equipment_picker_sheet.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/services/equipment_move_flow.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_location_picker_sheet.dart';
import 'package:submersion/features/equipment/presentation/widgets/move_equipment_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A lend asked about on a buddy's page in its sitting (issue #4527, phase
/// 3), held until Save: the gear picked, where it goes ([pick], the buddy
/// unless the diver chose elsewhere in the sheet), the answers to the parts
/// and status questions, and the diver it is filed under. The buddy's place
/// is found or created at Save, so a Cancel leaves no place behind.
class HeldLend {
  const HeldLend({
    required this.items,
    required this.pick,
    required this.plan,
    required this.diverId,
  });

  final List<EquipmentItem> items;
  final LocationPick pick;
  final EquipmentMovePlan plan;
  final String? diverId;
}

/// Lends gear from [buddy]'s page in its sitting: the picker, the move
/// sheet on the buddy, and the parts and status questions, all asked now,
/// with nothing written. [lent] and [returned] are the items the sitting
/// already holds as lent to and returned from the buddy. Null when the
/// diver backs out.
Future<HeldLend?> planLendGear(
  BuildContext context,
  WidgetRef ref,
  Buddy buddy, {
  Set<String> lent = const {},
  Set<String> returned = const {},
}) async {
  // Handled now, though awaited only at the end: a failure while the diver
  // is still choosing would otherwise go unhandled. The place is then filed
  // under no diver, as for a library with none.
  final diverIdFuture = ref
      .read(validatedCurrentDiverIdProvider.future)
      .then<String?>((id) => id, onError: (Object _) => null);
  final moves = ref.read(equipmentLocationMoveRepositoryProvider);
  final items = await _pickGearToLend(
    context,
    ref,
    buddy,
    lent: lent,
    returned: returned,
  );
  if (items == null || items.isEmpty || !context.mounted) return null;
  final draft = await showMoveEquipmentSheet(
    context,
    ref,
    itemCount: items.length,
    initialPick: BuddyPick(buddy),
  );
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
      items: items,
      targetKind: switch (draft.pick) {
        PlacePick(:final location) => location.kind,
        NoLocationPick() => null,
        BuddyPick() => EquipmentLocationKind.person,
      },
      movedAt: draft.movedAt,
      note: draft.note,
    );
  } catch (_) {
    // The parts could not be read: nothing is held, and the diver can
    // simply try again, as the move flow says.
    messenger.showSnackBar(SnackBar(content: Text(failed)));
    return null;
  }
  return HeldLend(
    items: items,
    pick: draft.pick,
    plan: plan,
    diverId: await diverIdFuture,
  );
}

/// The gear picker for lending to [buddy]: what they already have, or the
/// sitting holds as lent ([lent]), starts ticked. Null when dismissed or
/// when where the gear is could not be read (a SnackBar says so).
Future<List<EquipmentItem>?> _pickGearToLend(
  BuildContext context,
  WidgetRef ref,
  Buddy buddy, {
  Set<String> lent = const {},
  Set<String> returned = const {},
}) async {
  final failed = context.l10n.common_error_tryAgain;
  final messenger = ScaffoldMessenger.of(context);
  final Map<String, EquipmentLocation> current;
  try {
    current = await ref.read(currentEquipmentLocationsProvider.future);
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(failed)));
    return null;
  }
  if (!context.mounted) return null;
  final withBuddy = {
    for (final entry in current.entries)
      if (entry.value.buddyId == buddy.id && !returned.contains(entry.key))
        entry.key,
    ...lent,
  };
  return showModalBottomSheet<List<EquipmentItem>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => EquipmentPickerSheet(
        scrollController: scrollController,
        selectedEquipmentIds: withBuddy,
        title: sheetContext.l10n.buddies_action_lendGear,
        onEquipmentConfirmed: (picked) =>
            Navigator.of(sheetContext).pop(picked),
      ),
    ),
  );
}
