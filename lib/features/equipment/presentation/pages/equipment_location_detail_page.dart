import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_location_list_page.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_location_display.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_location_edit_dialog.dart';
import 'package:submersion/features/equipment/presentation/widgets/location_confirm_dialogs.dart';
import 'package:submersion/features/equipment/presentation/widgets/move_equipment_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Whether any move names the place, so Delete is offered only for a place
/// nothing has ever been at. Refreshes on every move.
final equipmentLocationInUseProvider = FutureProvider.autoDispose
    .family<bool, String>((ref, id) async {
      final moves = ref.watch(equipmentLocationMoveRepositoryProvider);
      ref.invalidateSelfWhen(moves.watchChanges());
      return ref.watch(equipmentLocationRepositoryProvider).isInUse(id);
    });

/// One place: its kind and notes, the gear there now, and edit, archive,
/// restore and delete.
class EquipmentLocationDetailPage extends ConsumerWidget {
  const EquipmentLocationDetailPage({super.key, required this.locationId});

  final String locationId;

  Future<void> _onMenu(
    BuildContext context,
    WidgetRef ref,
    EquipmentLocation place,
    String action,
  ) async {
    final repo = ref.read(equipmentLocationRepositoryProvider);
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      switch (action) {
        case 'archive':
          await repo.setArchived(place.id, archived: !place.isArchived);
        case 'delete':
          if (!await confirmLocationDelete(
            context,
            l10n.equipment_locations_deleteConfirm(place.name),
          )) {
            return;
          }
          // Throws if a move synced in since the menu opened: the place is
          // in use again, and the diver is told rather than the place lost.
          await repo.deleteLocation(place.id);
          if (context.mounted) context.pop();
      }
    } catch (_) {
      showLocationWriteFailed(messenger, l10n.common_error_tryAgain);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final place = ref
        .watch(allEquipmentLocationsByIdProvider)
        .value?[locationId];
    if (place == null) return Scaffold(appBar: AppBar());
    final current =
        ref.watch(currentEquipmentLocationsProvider).value ??
        const <String, EquipmentLocation>{};
    final items = [
      for (final item in itemsAtPlaces(ref))
        if (current[item.id]?.id == locationId) item,
    ];
    // Unknown until the check lands: offer Delete only once it is known safe.
    final inUse =
        ref.watch(equipmentLocationInUseProvider(place.id)).value ?? true;
    return Scaffold(
      appBar: AppBar(
        title: Text(place.name),
        actions: [
          // Bring everything here home (or on) in one go: the move flow's
          // parts and status prompts apply as from the equipment list.
          if (items.isNotEmpty)
            IconButton(
              key: const ValueKey('equipment_location_move_items'),
              icon: const Icon(Icons.move_down),
              tooltip: l10n.equipment_locations_moveItems,
              onPressed: () =>
                  showMoveEquipmentFlow(context, ref, items: items),
            ),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: l10n.equipment_locations_editTitle,
            onPressed: () =>
                showEquipmentLocationEditDialog(context, ref, existing: place),
          ),
          PopupMenuButton<String>(
            key: const ValueKey('equipment_location_menu'),
            onSelected: (action) => _onMenu(context, ref, place, action),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'archive',
                child: Text(
                  place.isArchived
                      ? l10n.equipment_locations_restore
                      : l10n.equipment_locations_archive,
                ),
              ),
              if (!inUse)
                PopupMenuItem(
                  value: 'delete',
                  child: Text(l10n.equipment_locations_delete),
                ),
            ],
          ),
        ],
      ),
      body: ListView(
        children: [
          ListTile(
            leading: Icon(place.kind.icon),
            title: Text(place.kind.localizedName(l10n)),
            subtitle: place.notes.isEmpty ? null : Text(place.notes),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              l10n.equipment_locations_itemsHere,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.equipment_locations_noItemsHere),
            ),
          for (final item in items)
            ListTile(
              key: ValueKey('equipment_location_item_${item.id}'),
              title: Text(item.name),
              subtitle: Text(item.type.localizedName(l10n)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/equipment/${item.id}'),
            ),
        ],
      ),
    );
  }
}
