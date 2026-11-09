import 'package:flutter/material.dart';

import 'package:submersion/features/equipment/presentation/widgets/equipment_arrange_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The bulk equipment editor's actions beside Add: apply a set, and sort.
class BulkGearActions extends StatelessWidget {
  const BulkGearActions({super.key, required this.onUseSet});

  /// Opens the equipment set picker.
  final VoidCallback onUseSet;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton.icon(
          onPressed: onUseSet,
          icon: const Icon(Icons.folder_special, size: 18),
          label: Text(l10n.diveLog_edit_useSet),
        ),
        // The same sort sheet as the single-dive gear list, and the same
        // shared setting (#2274). Icon only, so the section title keeps its
        // room on a phone.
        IconButton(
          icon: const Icon(Icons.sort, size: 18),
          tooltip: l10n.equipment_list_sortTooltip,
          onPressed: () => showEquipmentArrangeSheet(context),
        ),
      ],
    );
  }
}
