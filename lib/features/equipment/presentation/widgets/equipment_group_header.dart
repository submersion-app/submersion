import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The type heading above one run of gear in an arranged list (#1486, #1576).
///
/// Shared by every surface that renders arranged gear so the headings read the
/// same in the dive view, the edit form, the picker and the equipment sets.
///
/// The key is derived from the type rather than being a constant: several
/// headers are siblings inside one Column, and Flutter rejects duplicate keys
/// among siblings.
class EquipmentGroupHeader extends StatelessWidget {
  EquipmentGroupHeader({required this.type})
    : super(key: ValueKey('equipment-group-header-${type.name}'));

  final EquipmentType type;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      // A grouped gear list is a list of sections. Without the header flag
      // assistive tech sees one flat run of text, and a diver using a screen
      // reader cannot jump between gear types, which is the whole point of
      // grouping.
      child: Semantics(
        header: true,
        child: Text(
          type.localizedName(context.l10n),
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: colorScheme.primary),
        ),
      ),
    );
  }
}
