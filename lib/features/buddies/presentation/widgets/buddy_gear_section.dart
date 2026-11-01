import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/domain/services/gear_with_buddy.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_location_list_page.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/equipment/presentation/widgets/lend_gear_flow.dart';
import 'package:submersion/features/equipment/presentation/widgets/return_equipment_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/tile_subtitle_action.dart';

/// The diver's gear this buddy has (issue #3790): anything whose current place
/// links here, loaned or in everyday family use. Builds nothing, its spacing
/// included, when there is none, so most buddies show no trace of it.
class BuddyGearSection extends ConsumerWidget {
  final Buddy buddy;

  const BuddyGearSection({super.key, required this.buddy});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final current =
        ref.watch(currentEquipmentLocationsProvider).value ??
        const <String, EquipmentLocation>{};
    final rows = gearWithBuddy(buddy.id, itemsAtPlaces(ref), current);
    if (rows.isEmpty) return const SizedBox.shrink();

    final places =
        ref.watch(allEquipmentLocationsByIdProvider).value ??
        const <String, EquipmentLocation>{};
    final namePlaces =
        places.values.where((p) => p.buddyId == buddy.id).length > 1;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.buddies_gear_title(buddy.name),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    key: const ValueKey('buddy_gear_lend'),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.buddies_action_lendGear),
                    onPressed: () => showLendGearFlow(context, ref, buddy),
                  ),
                  if (rows.length > 1)
                    TextButton.icon(
                      key: const ValueKey('buddy_gear_all_returned'),
                      icon: const Icon(Icons.keyboard_return),
                      label: Text(l10n.buddies_gear_allReturned),
                      onPressed: () => showEquipmentReturnFlow(
                        context,
                        ref,
                        items: [for (final row in rows) row.item],
                        buddyId: buddy.id,
                      ),
                    ),
                ],
              ),
              for (final row in rows)
                _GearRow(
                  row: row,
                  namePlace: namePlaces,
                  // This section's context, not the row's: a returned item
                  // leaves the list as its move saves, and a prompt shown
                  // from a context that has gone is silently a no.
                  onReturned: () => showEquipmentReturnFlow(
                    context,
                    ref,
                    items: [row.item],
                    buddyId: buddy.id,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GearRow extends ConsumerWidget {
  const _GearRow({
    required this.row,
    required this.namePlace,
    required this.onReturned,
  });

  final GearWithBuddy row;
  final bool namePlace;
  final VoidCallback onReturned;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final units = ref.watch(unitFormatterProvider);
    final item = row.item;
    final moves =
        ref.watch(equipmentLocationMovesProvider(item.id)).value ?? const [];
    return ListTile(
      key: ValueKey('buddy_gear_${item.id}'),
      contentPadding: EdgeInsets.zero,
      title: Text(item.name),
      subtitle: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [
              item.type.localizedName(l10n),
              if (moves.isNotEmpty)
                l10n.equipment_location_since(
                  units.formatDate(moves.first.movedAt),
                ),
              // Family gear stays Active, so only a real loan is labelled.
              if (item.status == EquipmentStatus.loaned)
                item.status.localizedName(l10n),
              if (namePlace) row.place.name,
            ].join(' · '),
          ),
          TileSubtitleAction(
            actionKey: ValueKey('buddy_gear_returned_${item.id}'),
            label: l10n.buddies_gear_returned,
            onPressed: onReturned,
          ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/equipment/${item.id}'),
    );
  }
}
