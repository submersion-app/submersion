import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location_move.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_location_display.dart';
import 'package:submersion/features/equipment/presentation/widgets/location_move_edit_dialog.dart';
import 'package:submersion/features/equipment/presentation/widgets/move_equipment_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Where an item is now, a Move button, and its recent moves (the full log
/// behind "Show all"). Tapping a move edits or deletes it.
class EquipmentLocationCard extends ConsumerStatefulWidget {
  const EquipmentLocationCard({super.key, required this.equipment});

  final EquipmentItem equipment;

  @override
  ConsumerState<EquipmentLocationCard> createState() =>
      _EquipmentLocationCardState();
}

class _EquipmentLocationCardState extends ConsumerState<EquipmentLocationCard> {
  static const _recentCount = 3;
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final moves =
        ref.watch(equipmentLocationMovesProvider(widget.equipment.id)).value ??
        const <EquipmentLocationMove>[];
    final places =
        ref.watch(allEquipmentLocationsByIdProvider).value ??
        const <String, EquipmentLocation>{};
    final latest = moves.isEmpty ? null : moves.first;
    final current = latest == null ? null : places[latest.locationId];
    final shown = _showAll ? moves : moves.take(_recentCount).toList();

    return Card(
      key: const ValueKey('equipment_location_card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.equipment_location_card_title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  key: const ValueKey('equipment_location_move'),
                  icon: const Icon(Icons.move_down),
                  label: Text(l10n.equipment_location_moveButton),
                  onPressed: () => showMoveEquipmentFlow(
                    context,
                    ref,
                    items: [widget.equipment],
                  ),
                ),
              ],
            ),
            ListTile(
              key: const ValueKey('equipment_location_current'),
              contentPadding: EdgeInsets.zero,
              leading: Icon(current?.kind.icon ?? Icons.location_off_outlined),
              title: Text(current?.name ?? l10n.equipment_location_none),
              subtitle: current == null
                  ? null
                  : Text(
                      [
                        l10n.equipment_location_since(
                          units.formatDate(latest!.movedAt),
                        ),
                        if (latest.note.isNotEmpty) latest.note,
                      ].join('\n'),
                    ),
            ),
            if (moves.isNotEmpty) const Divider(),
            for (final m in shown) _historyRow(context, m, places, units),
            if (!_showAll && moves.length > _recentCount)
              TextButton(
                onPressed: () => setState(() => _showAll = true),
                child: Text(l10n.equipment_location_showAll),
              ),
          ],
        ),
      ),
    );
  }

  Widget _historyRow(
    BuildContext context,
    EquipmentLocationMove m,
    Map<String, EquipmentLocation> places,
    UnitFormatter units,
  ) {
    final place = places[m.locationId];
    return ListTile(
      key: ValueKey('equipment_location_move_${m.id}'),
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(place?.kind.icon ?? Icons.location_off_outlined, size: 20),
      title: Text(
        place?.name ?? context.l10n.equipment_location_history_cleared,
      ),
      subtitle: Text(
        [units.formatDate(m.movedAt), if (m.note.isNotEmpty) m.note].join(', '),
      ),
      trailing: const Icon(Icons.edit_outlined, size: 18),
      onTap: () => showLocationMoveEditDialog(context, ref, m),
    );
  }
}
