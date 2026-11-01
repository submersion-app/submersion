import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/equipment_picker_sheet.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/move_equipment_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Lends gear from [buddy]'s page (issue #3790): the diver ticks what goes,
/// then the move flow runs with the buddy already chosen. Gear they already
/// have is not offered.
Future<void> showLendGearFlow(
  BuildContext context,
  WidgetRef ref,
  Buddy buddy,
) async {
  final failed = context.l10n.common_error_tryAgain;
  final messenger = ScaffoldMessenger.of(context);
  final Map<String, EquipmentLocation> current;
  try {
    current = await ref.read(currentEquipmentLocationsProvider.future);
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(failed)));
    return;
  }
  if (!context.mounted) return;
  final withBuddy = {
    for (final entry in current.entries)
      if (entry.value.buddyId == buddy.id) entry.key,
  };
  final items = await showModalBottomSheet<List<EquipmentItem>>(
    context: context,
    isScrollControlled: true,
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
  if (items == null || items.isEmpty || !context.mounted) return;
  await showMoveEquipmentFlow(context, ref, items: items, lendTo: buddy);
}
