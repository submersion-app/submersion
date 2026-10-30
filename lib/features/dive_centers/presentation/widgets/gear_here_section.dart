import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/domain/services/gear_at_dive_center.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_location_list_page.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The diver's gear left at this center (issue #3623): anything whose
/// current place links here. Builds nothing, its divider included, when
/// there is none, so most centers show no trace of it. Matches the page's
/// other sections: a titled column with a 16 px gutter, no card.
class GearHereSection extends ConsumerWidget {
  final String centerId;

  const GearHereSection({super.key, required this.centerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final current =
        ref.watch(currentEquipmentLocationsProvider).value ??
        const <String, EquipmentLocation>{};
    final rows = gearAtDiveCenter(centerId, itemsAtPlaces(ref), current);
    if (rows.isEmpty) return const SizedBox.shrink();

    final places =
        ref.watch(equipmentLocationsProvider).value ??
        const <EquipmentLocation>[];
    final namePlaces =
        places.where((p) => p.diveCenterId == centerId).length > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            l10n.diveCenters_gearHere_title,
            style: theme.textTheme.titleMedium,
          ),
        ),
        for (final row in rows)
          ListTile(
            key: ValueKey('dive_center_gear_${row.item.id}'),
            title: Text(row.item.name),
            subtitle: Text(
              namePlaces
                  ? '${row.item.type.localizedName(l10n)} · ${row.place.name}'
                  : row.item.type.localizedName(l10n),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/equipment/${row.item.id}'),
          ),
      ],
    );
  }
}
