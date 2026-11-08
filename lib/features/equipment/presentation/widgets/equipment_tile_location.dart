import 'package:flutter/material.dart';

import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_location_display.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Where an item is kept, as one line of an equipment card's right-hand
/// column (issue #3625): the place kind's icon, then its name.
///
/// One line only, ellipsized: the column is width-capped and the tile caps
/// its trailing height, so a wrapped name would overflow.
class EquipmentTileLocation extends StatelessWidget {
  const EquipmentTileLocation({super.key, required this.location});

  final EquipmentLocation location;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    // Regular weight: a place is information, lighter than the badges that
    // share this line and ask for action.
    final style = theme.textTheme.labelSmall?.copyWith(
      color: color,
      fontWeight: FontWeight.w400,
    );
    return Semantics(
      label: context.l10n.equipment_location_tileSemantics(location.name),
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(location.kind.icon, size: 12, color: color),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                location.name,
                style: style,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
