import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_location_display.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The filter panel's place chips, any-of, plus "No location". Offers the
/// diver's active places and any already selected, so a filter on a place
/// since archived stays clearable. Hidden until the diver has a place.
class EquipmentLocationFilterSection extends ConsumerWidget {
  const EquipmentLocationFilterSection({
    super.key,
    required this.locationIds,
    required this.noLocation,
    required this.onChanged,
  });

  final Set<String> locationIds;
  final bool noLocation;
  final void Function(Set<String> locationIds, bool noLocation) onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final places = [
      for (final p
          in ref.watch(equipmentLocationsProvider).value ??
              const <EquipmentLocation>[])
        if (!p.isArchived || locationIds.contains(p.id)) p,
    ];
    if (places.isEmpty && !noLocation) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.equipment_filter_section_location,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in places)
                FilterChip(
                  key: ValueKey('equipment_filter_location_${p.id}'),
                  avatar: Icon(p.kind.icon, size: 16),
                  label: Text(p.name),
                  selected: locationIds.contains(p.id),
                  onSelected: (selected) => onChanged(
                    selected
                        ? {...locationIds, p.id}
                        : locationIds.where((id) => id != p.id).toSet(),
                    noLocation,
                  ),
                ),
              FilterChip(
                key: const ValueKey('equipment_filter_location_none'),
                avatar: const Icon(Icons.location_off_outlined, size: 16),
                label: Text(l10n.equipment_location_noLocation),
                selected: noLocation,
                onSelected: (selected) => onChanged(locationIds, selected),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
