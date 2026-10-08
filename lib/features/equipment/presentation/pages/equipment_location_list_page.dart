import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_location_display.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_location_edit_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Settings > Manage > Locations: the diver's places by kind, with how many
/// items are at each now. Archived places sit in a collapsed section.
class EquipmentLocationListPage extends ConsumerWidget {
  const EquipmentLocationListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final places =
        ref.watch(equipmentLocationsProvider).value ??
        const <EquipmentLocation>[];
    final counts = locationItemCounts(ref);
    final active = [
      for (final p in places)
        if (!p.isArchived) p,
    ];
    final archived = [
      for (final p in places)
        if (p.isArchived) p,
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.equipment_locations_title)),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('equipment_locations_add'),
        icon: const Icon(Icons.add),
        label: Text(l10n.equipment_locations_add),
        onPressed: () => showEquipmentLocationEditDialog(context, ref),
      ),
      body: places.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.equipment_locations_empty,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              // Clear of the extended FAB.
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                for (final kind in EquipmentLocationKind.values)
                  ..._kindSection(context, kind, [
                    for (final p in active)
                      if (p.kind == kind) p,
                  ], counts),
                if (archived.isNotEmpty)
                  ExpansionTile(
                    key: const ValueKey('equipment_locations_archived'),
                    title: Text(
                      l10n.equipment_locations_archivedSection(archived.length),
                    ),
                    children: [
                      for (final p in archived) _placeTile(context, p, counts),
                    ],
                  ),
              ],
            ),
    );
  }

  List<Widget> _kindSection(
    BuildContext context,
    EquipmentLocationKind kind,
    List<EquipmentLocation> places,
    Map<String, int> counts,
  ) {
    if (places.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Semantics(
          header: true,
          child: Text(
            kind.localizedName(context.l10n),
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
      ),
      for (final p in places) _placeTile(context, p, counts),
    ];
  }

  Widget _placeTile(
    BuildContext context,
    EquipmentLocation place,
    Map<String, int> counts,
  ) {
    return ListTile(
      key: ValueKey('equipment_location_${place.id}'),
      leading: Icon(place.kind.icon),
      title: Text(place.name),
      subtitle: place.notes.isEmpty ? null : Text(place.notes, maxLines: 1),
      trailing: Text(
        context.l10n.equipment_location_groupCount(counts[place.id] ?? 0),
      ),
      onTap: () => context.push('/equipment/locations/${place.id}'),
    );
  }
}

/// The gear at each place now, retired, sold and wishlist gear left out:
/// it is not with the diver, wherever it was last recorded.
Map<String, int> locationItemCounts(WidgetRef ref) {
  final current =
      ref.watch(currentEquipmentLocationsProvider).value ??
      const <String, EquipmentLocation>{};
  final counts = <String, int>{};
  for (final item in itemsAtPlaces(ref)) {
    final placeId = current[item.id]!.id;
    counts[placeId] = (counts[placeId] ?? 0) + 1;
  }
  return counts;
}

/// The diver's gear that is with them (not retired, sold, or still on the
/// wishlist) and has a current place. Watches both providers, so callers
/// rebuild on a move.
List<EquipmentItem> itemsAtPlaces(WidgetRef ref) {
  final items = ref.watch(allEquipmentProvider).value ?? const [];
  final current =
      ref.watch(currentEquipmentLocationsProvider).value ??
      const <String, EquipmentLocation>{};
  return [
    for (final item in items)
      if (item.status != EquipmentStatus.retired &&
          item.status != EquipmentStatus.sold &&
          item.status != EquipmentStatus.wanted &&
          current.containsKey(item.id))
        item,
  ];
}
