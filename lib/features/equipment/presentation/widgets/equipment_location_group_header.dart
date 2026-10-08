import 'package:flutter/material.dart';

import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_location_display.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A place's heading when the Equipment page groups by location: kind icon,
/// name ("No location" for null) and item count. A header for assistive
/// tech, like the type headings under it, so a screen reader can jump
/// between places.
class EquipmentLocationGroupHeader extends StatelessWidget {
  EquipmentLocationGroupHeader({required this.location, required this.count})
    : super(
        key: ValueKey('equipment-location-header-${location?.id ?? 'none'}'),
      );

  final EquipmentLocation? location;
  final int count;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Semantics(
        header: true,
        child: Row(
          children: [
            Icon(
              location?.kind.icon ?? Icons.location_off_outlined,
              size: 18,
              color: color,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                location?.name ?? l10n.equipment_location_noLocation,
                style: theme.textTheme.titleSmall?.copyWith(color: color),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              l10n.equipment_location_groupCount(count),
              style: theme.textTheme.labelMedium,
            ),
          ],
        ),
      ),
    );
  }
}
