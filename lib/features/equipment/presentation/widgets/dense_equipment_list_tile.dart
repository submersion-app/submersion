import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

/// Single-row flat tile for the equipment list (maximum density).
///
/// Row: Equipment name (expanded) | Type label (~80px) | Service status (~80px) | Chevron
class DenseEquipmentListTile extends StatelessWidget {
  final EquipmentItem item;
  final bool isSelected;
  final VoidCallback? onTap;

  const DenseEquipmentListTile({
    super.key,
    required this.item,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final rowColor = isSelected
        ? colorScheme.primaryContainer.withValues(alpha: 0.3)
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
                    item.type.displayName,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: secondaryTextColor),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: 8),
                // Service status indicator (~80px)
                SizedBox(width: 80, child: _buildServiceStatus(context)),
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

  Widget _buildServiceStatus(BuildContext context) {
    final theme = Theme.of(context);

    if (item.isServiceDue) {
      return Text(
        'Service Due',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.error,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.right,
        overflow: TextOverflow.ellipsis,
      );
    }

    if (item.daysUntilService != null) {
      final days = item.daysUntilService!;
      return Text(
        'In $days days',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        textAlign: TextAlign.right,
        overflow: TextOverflow.ellipsis,
      );
    }

    if (item.status != EquipmentStatus.active) {
      return Text(
        item.status.displayName,
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
