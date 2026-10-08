import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/equipment/presentation/providers/equipment_share_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A small chip naming the profile that owns an item (issue #2046), shown
/// where the item belongs to someone other than the profile in context.
class EquipmentOwnerChip extends ConsumerWidget {
  final String? ownerId;

  const EquipmentOwnerChip({super.key, required this.ownerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final names = ref.watch(diverNamesByIdProvider).value ?? const {};
    final name =
        (ownerId == null ? null : names[ownerId]) ??
        l10n.equipment_owner_unknown;
    final theme = Theme.of(context);
    return Semantics(
      label: l10n.equipment_ownerChip_semanticLabel(name),
      excludeSemantics: true,
      child: Chip(
        key: ValueKey('equipment-owner-chip-$ownerId'),
        avatar: Icon(
          Icons.person_outline,
          size: 14,
          color: theme.colorScheme.onSecondaryContainer,
        ),
        label: Text(name),
        labelStyle: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
        ),
        backgroundColor: theme.colorScheme.secondaryContainer,
        side: BorderSide.none,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: EdgeInsets.zero,
      ),
    );
  }
}
