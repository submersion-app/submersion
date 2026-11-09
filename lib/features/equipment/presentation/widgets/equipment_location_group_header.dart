import 'package:flutter/material.dart';

import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_location_display.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/collapsible_group_header.dart';

/// A place's heading when the Equipment page groups by location: the
/// strong level of the page (issue #4184), bold, with its kind icon, name
/// ("No location" for null) and item count. Tapping it folds the place; a
/// folded place shows [summary] under its name. A heading for assistive
/// tech, so a screen reader can jump between places.
class EquipmentLocationGroupHeader extends StatelessWidget {
  EquipmentLocationGroupHeader({
    required this.location,
    required this.count,
    required this.isExpanded,
    required this.onTap,
    this.summary,
  }) : super(
         key: ValueKey('equipment-location-header-${location?.id ?? 'none'}'),
       );

  final EquipmentLocation? location;
  final int count;
  final bool isExpanded;
  final VoidCallback onTap;
  final String? summary;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return CollapsibleGroupHeader(
      label: location?.name ?? l10n.equipment_location_noLocation,
      countLabel: l10n.equipment_location_groupCount(count),
      isExpanded: isExpanded,
      onTap: onTap,
      summary: summary,
      titleWeight: FontWeight.w700,
      isHeading: true,
      leading: Icon(
        location?.kind.icon ?? Icons.location_off_outlined,
        size: 18,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
