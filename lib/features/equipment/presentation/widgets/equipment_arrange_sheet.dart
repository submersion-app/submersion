import 'package:flutter/material.dart';

import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/constants/sort_options_display.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_type_order.dart';
import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_arrangement_provider.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_arrangement_display.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Opens the shared arrange sheet.
///
/// Every gear surface uses this one entry point so the diver's choice is the
/// same wherever they change it.
Future<void> showEquipmentArrangeSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const EquipmentArrangeSheet(),
  );
}

/// The three-axis control for how a gear list is grouped and ordered
/// (#1486, #1576).
///
/// Deliberately a sibling of `SortBottomSheet` rather than a generalization of
/// it: that sheet is a single-axis control used by ten list pages, and
/// widening it to three axes to serve one caller would complicate every
/// existing caller for no benefit.
class EquipmentArrangeSheet extends ConsumerWidget {
  const EquipmentArrangeSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final arrangement = ref.watch(equipmentArrangementNotifierProvider);

    // Grouping without a type ordering would draw headers in an arbitrary
    // sequence, which is the very complaint this feature answers, so
    // arrangeEquipment forces headers off in that case. Disable the switch
    // rather than let the diver flip a control that does nothing.
    final canGroup = arrangement.typeOrder != EquipmentTypeOrder.none;
    // Same condition, named for the direction toggle: with no type ordering
    // there is nothing to reverse.
    final canGroupOrOrder = canGroup;

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    // Flexible with an ellipsis rather than a bare Text: the
                    // longest translation of this title is 23 characters and
                    // an inflexible one overflows a narrow phone.
                    Flexible(
                      child: Semantics(
                        header: true,
                        child: Text(
                          l10n.equipment_arrange_title,
                          style: textTheme.titleLarge,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: l10n.common_action_close,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              SwitchListTile(
                value: arrangement.groupByType && canGroup,
                onChanged: canGroup
                    ? (value) => _apply(
                        context,
                        ref,
                        arrangement.copyWith(groupByType: value),
                      )
                    : null,
                title: Text(l10n.equipment_arrange_groupByType),
                subtitle: Text(l10n.equipment_arrange_groupByTypeSubtitle),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.equipment_arrange_typeOrderLabel,
                        style: textTheme.labelLarge,
                      ),
                    ),
                    // #1486 asks for "toe to head" and #1576 for descending
                    // by head to toe, so the type axis carries its own
                    // direction, independent of the item sort below.
                    SegmentedButton<bool>(
                      segments: [
                        ButtonSegment(
                          value: false,
                          icon: Icon(SortDirection.ascending.icon, size: 18),
                          tooltip: SortDirection.ascending.localizedName(l10n),
                        ),
                        ButtonSegment(
                          value: true,
                          icon: Icon(SortDirection.descending.icon, size: 18),
                          tooltip: SortDirection.descending.localizedName(l10n),
                        ),
                      ],
                      selected: {arrangement.typeOrderDescending},
                      showSelectedIcon: false,
                      onSelectionChanged: canGroupOrOrder
                          ? (selected) => _apply(
                              context,
                              ref,
                              arrangement.copyWith(
                                typeOrderDescending: selected.first,
                              ),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
              // RadioGroup rather than per-tile groupValue/onChanged, which
              // Flutter deprecated after 3.32.
              RadioGroup<EquipmentTypeOrder>(
                groupValue: arrangement.typeOrder,
                onChanged: (value) {
                  if (value == null) return;
                  _apply(context, ref, arrangement.copyWith(typeOrder: value));
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final order in EquipmentTypeOrder.values)
                      RadioListTile<EquipmentTypeOrder>(
                        value: order,
                        title: Text(order.localizedName(l10n)),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        // "Then by" only makes sense when something ordered
                        // the list first.
                        arrangement.groupByType && canGroup
                            ? l10n.equipment_arrange_itemOrderLabel
                            : l10n.equipment_arrange_itemOrderLabelFlat,
                        style: textTheme.labelLarge,
                      ),
                    ),
                    SegmentedButton<SortDirection>(
                      segments: [
                        for (final direction in SortDirection.values)
                          ButtonSegment(
                            value: direction,
                            icon: Icon(direction.icon, size: 18),
                            tooltip: direction.localizedName(l10n),
                          ),
                      ],
                      selected: {arrangement.itemSortDirection},
                      showSelectedIcon: false,
                      onSelectionChanged: (selected) => _apply(
                        context,
                        ref,
                        arrangement.copyWith(itemSortDirection: selected.first),
                      ),
                    ),
                  ],
                ),
              ),
              RadioGroup<EquipmentItemSortField>(
                groupValue: arrangement.itemSortField,
                onChanged: (value) {
                  if (value == null) return;
                  _apply(
                    context,
                    ref,
                    arrangement.copyWith(itemSortField: value),
                  );
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final field in EquipmentItemSortField.values)
                      RadioListTile<EquipmentItemSortField>(
                        value: field,
                        secondary: Icon(field.icon),
                        title: Text(field.localizedName(l10n)),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: TextButton(
                    onPressed: () =>
                        _apply(context, ref, EquipmentArrangement.defaults),
                    child: Text(l10n.equipment_arrange_reset),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Persists [next], telling the diver when the write did not take.
  ///
  /// The notifier leaves state untouched on a failed write, so the sheet keeps
  /// showing what is actually stored. Without a message the control would just
  /// appear to snap back for no reason.
  Future<void> _apply(
    BuildContext context,
    WidgetRef ref,
    EquipmentArrangement next,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final message = context.l10n.equipment_arrange_saveFailed;
    try {
      await ref
          .read(equipmentArrangementNotifierProvider.notifier)
          .setArrangement(next);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }
}
