import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_location_display.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_location_edit_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// What the place picker returned.
sealed class LocationPick {
  const LocationPick();
}

/// One of the diver's places.
class PlacePick extends LocationPick {
  const PlacePick(this.location);
  final EquipmentLocation location;
}

/// "No location": clears where the item is.
class NoLocationPick extends LocationPick {
  const NoLocationPick();
}

/// Picks one of the diver's active places, "No location", or a place made
/// on the spot. Null when dismissed.
Future<LocationPick?> showEquipmentLocationPickerSheet(
  BuildContext context,
  WidgetRef ref,
) {
  return showModalBottomSheet<LocationPick>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const FractionallySizedBox(
      heightFactor: 0.8,
      child: _EquipmentLocationPicker(),
    ),
  );
}

class _EquipmentLocationPicker extends ConsumerStatefulWidget {
  const _EquipmentLocationPicker();

  @override
  ConsumerState<_EquipmentLocationPicker> createState() =>
      _EquipmentLocationPickerState();
}

class _EquipmentLocationPickerState
    extends ConsumerState<_EquipmentLocationPicker> {
  String _search = '';

  Future<void> _createPlace() async {
    final created = await showEquipmentLocationEditDialog(
      context,
      ref,
      initialName: _search,
    );
    if (created != null && mounted) {
      Navigator.of(context).pop(PlacePick(created));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final query = _search.trim().toLowerCase();
    final places = [
      for (final p
          in ref.watch(equipmentLocationsProvider).value ??
              const <EquipmentLocation>[])
        if (!p.isArchived &&
            (query.isEmpty || p.name.toLowerCase().contains(query)))
          p,
    ];
    return SafeArea(
      child: Column(
        children: [
          ListTile(
            title: Text(
              l10n.equipment_location_picker_title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              tooltip: l10n.common_action_close,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.equipment_location_picker_search,
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                ListTile(
                  key: const ValueKey('equipment_location_picker_new'),
                  leading: const Icon(Icons.add),
                  title: Text(l10n.equipment_location_picker_newPlace),
                  subtitle: query.isEmpty ? null : Text(_search.trim()),
                  onTap: _createPlace,
                ),
                ListTile(
                  key: const ValueKey('equipment_location_picker_none'),
                  leading: const Icon(Icons.location_off_outlined),
                  title: Text(l10n.equipment_location_noLocation),
                  onTap: () =>
                      Navigator.of(context).pop(const NoLocationPick()),
                ),
                const Divider(height: 1),
                for (final kind in EquipmentLocationKind.values)
                  ..._section(context, kind, [
                    for (final p in places)
                      if (p.kind == kind) p,
                  ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _section(
    BuildContext context,
    EquipmentLocationKind kind,
    List<EquipmentLocation> places,
  ) {
    if (places.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(
          kind.localizedName(context.l10n),
          style: Theme.of(context).textTheme.labelLarge,
        ),
      ),
      for (final p in places)
        ListTile(
          key: ValueKey('equipment_location_picker_${p.id}'),
          leading: Icon(kind.icon),
          title: Text(p.name),
          subtitle: p.notes.isEmpty ? null : Text(p.notes, maxLines: 1),
          onTap: () => Navigator.of(context).pop(PlacePick(p)),
        ),
    ];
  }
}
