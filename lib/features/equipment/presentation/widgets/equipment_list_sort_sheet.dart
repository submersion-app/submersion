import 'package:flutter/material.dart';

import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/constants/sort_options_display.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_type_order.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_arrangement_provider.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_sort_sheet_layout.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Opens the Equipment page's sort sheet.
///
/// Shared by the phone app bar, the master-detail compact bar and table
/// mode's toolbar so all three edit the same sort. Table mode passes
/// [showGrouping] false: the table stays flat, so grouping controls there
/// would change nothing on screen.
Future<void> showEquipmentListSortSheet(
  BuildContext context, {
  bool showGrouping = true,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => EquipmentListSortSheet(showGrouping: showGrouping),
  );
}

/// The Equipment page's sort sheet: the shared gear grouping on top, the
/// page's own item sort below.
///
/// The grouping controls edit the one gear arrangement every surface shares,
/// so grouping the inventory here also groups the gear on a dive. The item
/// sort stays the page's own because it offers Service Due, which needs the
/// clock-urgency map the dive surfaces never load.
class EquipmentListSortSheet extends ConsumerWidget {
  const EquipmentListSortSheet({super.key, this.showGrouping = true});

  final bool showGrouping;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final sort = ref.watch(equipmentSortProvider);
    final arrangement = ref.watch(equipmentArrangementProvider);
    // Without the grouping controls the table is ordered by this sort alone,
    // so "Then by" would name a first key that is not there.
    final grouped =
        showGrouping &&
        arrangement.groupByType &&
        arrangement.typeOrder != EquipmentTypeOrder.none;

    void setSort(SortState<EquipmentSortField> next) =>
        ref.read(equipmentSortProvider.notifier).state = next;

    return EquipmentSortSheetLayout<EquipmentSortField>(
      direction: sort.direction,
      onDirectionChanged: (direction) =>
          setSort(SortState(field: sort.field, direction: direction)),
      fieldsLabel: grouped
          ? l10n.equipment_arrange_itemOrderLabel
          : l10n.equipment_arrange_itemOrderLabelFlat,
      fields: EquipmentSortField.values,
      selectedField: sort.field,
      fieldLabel: (field) => field.localizedName(l10n),
      fieldIcon: (field) => field.icon,
      onFieldSelected: (field) =>
          setSort(SortState(field: field, direction: sort.direction)),
      showGrouping: showGrouping,
    );
  }
}
