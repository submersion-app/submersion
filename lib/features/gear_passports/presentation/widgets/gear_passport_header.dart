import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_share_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_owner_sections.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_type_icon.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_owner_chip.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Name, type, brand and model, serial, and the owner when another
/// profile's gear is shared with this one (gear tag spec 9).
class GearPassportHeader extends ConsumerWidget {
  const GearPassportHeader({super.key, required this.equipment});

  final EquipmentItem equipment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final makeModel = [
      if (equipment.brand?.trim().isNotEmpty ?? false) equipment.brand!.trim(),
      if (equipment.model?.trim().isNotEmpty ?? false) equipment.model!.trim(),
    ].join(' ');
    final serial = equipment.serialNumber?.trim();
    // While the active diver reloads (a profile switch) the provider keeps
    // the previous id; treat that as unknown rather than judge the chip
    // against the wrong diver.
    final activeDiver = ref.watch(validatedCurrentDiverIdProvider);
    final showOwner = showsOwnerChip(
      equipment,
      activeDiver.isLoading ? null : activeDiver.value,
      multipleDivers: ref.watch(hasMultipleDiversProvider),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(equipment.name, style: theme.textTheme.headlineMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Chip(
              avatar: Icon(equipmentTypeIcon(equipment.type), size: 18),
              label: Text(equipment.type.localizedName(l10n)),
              visualDensity: VisualDensity.compact,
            ),
            if (showOwner) EquipmentOwnerChip(ownerId: equipment.diverId),
          ],
        ),
        if (makeModel.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(makeModel, style: theme.textTheme.titleMedium),
        ],
        if (serial != null && serial.isNotEmpty)
          Text(
            l10n.passport_foreign_serial(serial),
            style: theme.textTheme.bodyMedium,
          ),
      ],
    );
  }
}
