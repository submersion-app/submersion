import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_location_display.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The filter panel's place chips, any-of, plus "No location". One chip per
/// place name, ignoring case, since the filter matches by name: two places
/// the diver gave one name are one choice. Offers the active places and any
/// name already selected, so a filter on a place since archived stays
/// clearable. Hidden until the diver has a place.
class EquipmentLocationFilterSection extends ConsumerWidget {
  const EquipmentLocationFilterSection({
    super.key,
    required this.locationNames,
    required this.noLocation,
    required this.onChanged,
  });

  final Set<String> locationNames;
  final bool noLocation;
  final void Function(Set<String> locationNames, bool noLocation) onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final selected = {for (final n in locationNames) n.toLowerCase()};
    // First place per name, so each name shows once with its kind's icon.
    final byName = <String, EquipmentLocation>{};
    for (final p
        in ref.watch(equipmentLocationsProvider).value ??
            const <EquipmentLocation>[]) {
      final key = p.name.toLowerCase();
      if (p.isArchived && !selected.contains(key)) continue;
      byName.putIfAbsent(key, () => p);
    }
    final places = byName.values.toList();
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
                  selected: selected.contains(p.name.toLowerCase()),
                  onSelected: (on) => onChanged(
                    on
                        ? {...locationNames, p.name}
                        : {
                            for (final n in locationNames)
                              if (n.toLowerCase() != p.name.toLowerCase()) n,
                          },
                    noLocation,
                  ),
                ),
              FilterChip(
                key: const ValueKey('equipment_filter_location_none'),
                avatar: const Icon(Icons.location_off_outlined, size: 16),
                label: Text(l10n.equipment_location_noLocation),
                selected: noLocation,
                onSelected: (selected) => onChanged(locationNames, selected),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
