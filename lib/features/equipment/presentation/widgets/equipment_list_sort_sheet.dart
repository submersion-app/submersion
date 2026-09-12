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
    // The type order is the first key whether or not headings are drawn: a
    // flat list is still ordered by type before this sort. Without the
    // grouping controls (the table) this sort is the only key, so "Then by"
    // would name a first key that is not there.
    //
    // The table's sheet never touches the arrangement, so it is only watched
    // when the grouping is shown: watching it would otherwise start the
    // arrangement notifier's settings read and subscription for nothing.
    final typesOrderFirst =
        showGrouping &&
        ref.watch(equipmentArrangementProvider).typeOrder !=
            EquipmentTypeOrder.none;

    // Reads the sort as it is NOW rather than the `sort` this build saw: the
    // sheet stays open, and two taps before the next frame would otherwise
    // both start from the same snapshot, the second undoing the first.
    void updateSort({EquipmentSortField? field, SortDirection? direction}) {
      final notifier = ref.read(equipmentSortProvider.notifier);
      final current = notifier.state;
      notifier.state = SortState(
        field: field ?? current.field,
        direction: direction ?? current.direction,
      );
    }

    return EquipmentSortSheetLayout<EquipmentSortField>(
      direction: sort.direction,
      onDirectionChanged: (direction) => updateSort(direction: direction),
      fieldsLabel: typesOrderFirst
          ? l10n.equipment_arrange_itemOrderLabel
          : l10n.equipment_arrange_itemOrderLabelFlat,
      fields: EquipmentSortField.values,
      selectedField: sort.field,
      fieldLabel: (field) => field.localizedName(l10n),
      fieldIcon: (field) => field.icon,
      onFieldSelected: (field) => updateSort(field: field),
      showGrouping: showGrouping,
    );
  }
}
