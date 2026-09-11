import 'package:flutter/material.dart';

import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/constants/sort_options_display.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_type_order.dart';
import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_arrangement_provider.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_arrangement_display.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The type axis of the diver's gear arrangement: whether to draw a heading
/// per kind of gear, and which order the kinds come in (#1486, #1576).
///
/// Rendered by both gear sort sheets, the dive surfaces' and the Equipment
/// page's, so the one shared preference is edited with the same control
/// wherever the diver meets it.
class EquipmentGroupingControls extends ConsumerWidget {
  const EquipmentGroupingControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final arrangement = ref.watch(equipmentArrangementNotifierProvider);

    // Grouping without a type ordering would draw headers in an arbitrary
    // sequence, which is the very complaint this feature answers, so
    // arrangeEquipment forces headers off in that case. Disable the switch
    // and the direction rather than offer controls that do nothing.
    final canGroup = arrangement.typeOrder != EquipmentTypeOrder.none;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          value: arrangement.groupByType && canGroup,
          // A toggle of the arrangement as it is when the change runs, not a
          // set to the switch's next value: the switch shows the SAVED state,
          // so two taps before the first write lands would otherwise both
          // ask for the same value and the second could not undo the first.
          onChanged: canGroup
              ? (_) => applyEquipmentArrangement(
                  context,
                  ref,
                  (current) =>
                      current.copyWith(groupByType: !current.groupByType),
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
              // #1486 asks for "toe to head" and #1576 for descending by head
              // to toe, so the type axis carries its own direction,
              // independent of the item sort.
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
                onSelectionChanged: canGroup
                    ? (selected) => applyEquipmentArrangement(
                        context,
                        ref,
                        (current) => current.copyWith(
                          typeOrderDescending: selected.first,
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
        // RadioGroup rather than per-tile groupValue/onChanged, which Flutter
        // deprecated after 3.32.
        RadioGroup<EquipmentTypeOrder>(
          groupValue: arrangement.typeOrder,
          onChanged: (value) {
            if (value == null) return;
            applyEquipmentArrangement(
              context,
              ref,
              (current) => current.copyWith(typeOrder: value),
            );
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
      ],
    );
  }
}

/// Applies [change] to the diver's arrangement and persists it, telling the
/// diver when the write did not take.
///
/// Takes a change rather than a finished arrangement: the sheet stays open,
/// and the arrangement it last rendered can be a write behind, so building
/// on it would undo a change still in flight. The notifier queues [change]
/// and applies it to the stored arrangement when its turn comes, after the
/// first load and after every earlier change has saved or failed.
///
/// The notifier leaves state untouched on a failed write, so the sheet keeps
/// showing what is actually stored. Without a message the control would just
/// appear to snap back for no reason.
Future<void> applyEquipmentArrangement(
  BuildContext context,
  WidgetRef ref,
  EquipmentArrangement Function(EquipmentArrangement current) change,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final message = context.l10n.equipment_arrange_saveFailed;
  try {
    await ref
        .read(equipmentArrangementNotifierProvider.notifier)
        .updateArrangement(change);
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}
