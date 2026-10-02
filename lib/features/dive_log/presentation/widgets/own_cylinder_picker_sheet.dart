import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/icons/mdi_icons.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_share_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_owner_sections.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_owner_chip.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The cylinders a tank can be filled from: tank gear in [gear], spares
/// left out as in every gear picker (#1803). Gear another diver shared is
/// included, since shared gear is usable on a dive (#2046); the sheet marks
/// it with its owner.
List<EquipmentItem> ownCylinders(List<EquipmentItem> gear) => [
  for (final item in gear)
    if (item.type == EquipmentType.tank && item.status != EquipmentStatus.spare)
      item,
];

/// Lets the diver choose one of their own [cylinders] to fill a dive tank
/// from (issue #2599). Resolves to the chosen cylinder, or null when the
/// sheet is dismissed.
Future<EquipmentItem?> showOwnCylinderPicker(
  BuildContext context, {
  required List<EquipmentItem> cylinders,
  required UnitFormatter units,
}) {
  return showModalBottomSheet<EquipmentItem>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _OwnCylinderPickerSheet(cylinders: cylinders, units: units),
  );
}

class _OwnCylinderPickerSheet extends ConsumerWidget {
  const _OwnCylinderPickerSheet({required this.cylinders, required this.units});

  final List<EquipmentItem> cylinders;
  final UnitFormatter units;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final activeDiverId = ref.watch(validatedCurrentDiverIdProvider).value;
    final multipleDivers = ref.watch(hasMultipleDiversProvider);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
            child: Text(
              l10n.diveLog_tank_ownCylinderTitle,
              style: theme.textTheme.titleMedium,
            ),
          ),
          // Says what picking does, so choosing a cylinder here is not
          // mistaken for the equipment list it also lands in.
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              l10n.diveLog_tank_ownCylinderHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final cylinder in cylinders)
                  ListTile(
                    key: Key('own-cylinder-${cylinder.id}'),
                    leading: const Icon(MdiIcons.divingScubaTank),
                    title: Text(cylinder.name),
                    subtitle: cylinder.volumeL == null
                        ? null
                        : Text(
                            units.formatTankVolume(
                              cylinder.volumeL,
                              cylinder.workingPressureBar,
                            ),
                          ),
                    // A shared cylinder is not the diver's own: name its
                    // owner, as the dive's gear list does.
                    trailing:
                        showsOwnerChip(
                          cylinder,
                          activeDiverId,
                          multipleDivers: multipleDivers,
                        )
                        ? EquipmentOwnerChip(ownerId: cylinder.diverId)
                        : null,
                    onTap: () => Navigator.of(context).pop(cylinder),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
