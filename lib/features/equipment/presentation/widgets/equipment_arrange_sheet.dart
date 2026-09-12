import 'package:flutter/material.dart';

import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/constants/sort_options_display.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_type_order.dart';
import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_arrangement_provider.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_grouping_controls.dart'
    show applyEquipmentArrangement;
import 'package:submersion/features/equipment/presentation/widgets/equipment_sort_sheet_layout.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Opens the shared gear sort sheet for the dive surfaces.
///
/// Every gear surface on a dive uses this one entry point so the diver's
/// choice is the same wherever they change it.
Future<void> showEquipmentArrangeSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const EquipmentArrangeSheet(),
  );
}

/// How a gear list on a dive is grouped and ordered (#1486, #1576).
///
/// Laid out exactly like the Equipment page's sort sheet
/// ([EquipmentSortSheetLayout]), so the diver reads the same control on both
/// surfaces. Every axis here, item sort included, is the one persisted
/// [EquipmentArrangement].
///
/// Deliberately not a `SortBottomSheet`: that sheet is a single-axis control
/// used by ten list pages and closes on the first pick, and widening it to
/// three axes to serve the gear surfaces would complicate every other caller.
class EquipmentArrangeSheet extends ConsumerWidget {
  const EquipmentArrangeSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final arrangement = ref.watch(equipmentArrangementNotifierProvider);
    // The type order is the first key whether or not headings are drawn: a
    // flat list is still ordered by type before the item field.
    final typesOrderFirst = arrangement.typeOrder != EquipmentTypeOrder.none;

    return EquipmentSortSheetLayout<EquipmentItemSortField>(
      direction: arrangement.itemSortDirection,
      onDirectionChanged: (direction) => applyEquipmentArrangement(
        context,
        ref,
        (current) => current.copyWith(itemSortDirection: direction),
      ),
      // "Then by" only makes sense when something ordered the list first.
      fieldsLabel: typesOrderFirst
          ? l10n.equipment_arrange_itemOrderLabel
          : l10n.equipment_arrange_itemOrderLabelFlat,
      fields: EquipmentItemSortField.values,
      selectedField: arrangement.itemSortField,
      fieldLabel: (field) => field.localizedName(l10n),
      fieldIcon: (field) => field.icon,
      onFieldSelected: (field) => applyEquipmentArrangement(
        context,
        ref,
        (current) => current.copyWith(itemSortField: field),
      ),
      footer: Align(
        alignment: AlignmentDirectional.centerEnd,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: TextButton(
            onPressed: () => applyEquipmentArrangement(
              context,
              ref,
              (_) => EquipmentArrangement.defaults,
            ),
            child: Text(l10n.equipment_arrange_reset),
          ),
        ),
      ),
    );
  }
}
