import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/shared/selection/selection_checkbox_slot.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Single-row flat tile for the equipment list (maximum density).
///
/// Row: Equipment name (expanded) | Type label (~80px) | Service status (~80px) | Chevron
class DenseEquipmentListTile extends ConsumerWidget {
  final EquipmentItem item;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool isSelectionMode;
  final bool isChecked;
  final ValueChanged<bool>? onCheckChanged;

  const DenseEquipmentListTile({
    super.key,
    required this.item,
    this.isSelected = false,
    this.onTap,
    this.isSelectionMode = false,
    this.isChecked = false,
    this.onCheckChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The rollup (issue #1487): a due part lights its assembly.
    final rollup = ref.watch(equipmentRollupClockProvider).value?[item.id];
    final worstClock =
        rollup == null || rollup.status.severity == ServiceClockSeverity.ok
        ? null
        : rollup;
    final isAssembly =
        ref
            .watch(equipmentComponentsIndexProvider)
            .value
            ?.isAssembly(item.id) ??
        false;
    final colorScheme = Theme.of(context).colorScheme;
    final rowColor = isSelected
        ? colorScheme.primaryContainer.withValues(alpha: 0.5)
        : null;
    final secondaryTextColor = colorScheme.onSurfaceVariant;

    return Semantics(
      button: true,
      label: item.name,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: rowColor,
          border: Border(
            bottom: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              width: 0.5,
            ),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                SelectionCheckboxSlot(
                  isSelectionMode: isSelectionMode,
                  isChecked: isChecked,
                  onChanged: onCheckChanged,
                  gap: 8,
                ),
                if (isAssembly) ...[
                  Icon(
                    Icons.account_tree_outlined,
                    size: 14,
                    color: secondaryTextColor,
                  ),
                  const SizedBox(width: 4),
                ],
                // Equipment name (expanded)
                Expanded(
                  child: Text(
                    item.name,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                // Type label (~80px)
                SizedBox(
                  width: 80,
                  child: Text(
                    item.type.localizedName(context.l10n),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: secondaryTextColor),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: 8),
                // Service status indicator (~80px)
                SizedBox(
                  width: 80,
                  child: _buildServiceStatus(context, worstClock),
                ),
                ExcludeSemantics(
                  child: Icon(
                    Icons.chevron_right,
                    color: secondaryTextColor,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildServiceStatus(BuildContext context, RollupClock? worstClock) {
    final theme = Theme.of(context);

    if (worstClock != null) {
      final overdue =
          worstClock.status.severity == ServiceClockSeverity.overdue;
      final kindLabel = worstClock.ownerId == item.id
          ? worstClock.status.kind.name
          : context.l10n.equipment_components_rollupClock(
              worstClock.ownerName,
              worstClock.status.kind.name,
            );
      return Text(
        kindLabel,
        style: theme.textTheme.labelSmall?.copyWith(
          color: overdue ? theme.colorScheme.error : theme.colorScheme.tertiary,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.right,
        overflow: TextOverflow.ellipsis,
      );
    }

    if (item.status != EquipmentStatus.active) {
      return Text(
        item.status.localizedName(context.l10n),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.right,
        overflow: TextOverflow.ellipsis,
      );
    }

    return const SizedBox.shrink();
  }
}
