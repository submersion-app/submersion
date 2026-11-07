import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/domain/entities/bulk_edit_request.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One equipment set staged in a bulk edit (#4284).
typedef BulkStagedSet = ({String id, String name});

/// Which set switched each gear row on, after [setId] switched on
/// [itemIds]: an item a set already switched on keeps that set, so the first
/// set wins, as it does on a dive (`GearExpander`).
Map<String, String> withSetItems(
  Map<String, String> setOf,
  String setId,
  Iterable<String> itemIds,
) => {
  ...setOf,
  for (final id in itemIds)
    if (!setOf.containsKey(id)) id: setId,
};

/// The gear adds of a bulk edit: an item a set switched on is added through
/// that set, so it carries the set as it would on the dive edit page; an
/// item picked by hand carries none.
List<EquipmentOp> equipmentAddOps(
  List<String> addIds,
  Map<String, String> setOf,
) {
  final groups = <String?, List<String>>{};
  for (final id in addIds) {
    (groups[setOf[id]] ??= []).add(id);
  }
  return [
    for (final MapEntry(key: setId, value: ids) in groups.entries)
      EquipmentOp(
        mode: BulkCollectionMode.add,
        equipmentIds: ids,
        viaSetId: setId,
      ),
  ];
}

/// The bulk equipment group's "Remove set" row: the button that stages a
/// set, and the staged sets as chips, each removable again. A staged set
/// comes off every selected dive with the gear it brought.
class BulkEquipmentSetRemovals extends StatelessWidget {
  const BulkEquipmentSetRemovals({
    super.key,
    required this.sets,
    required this.onPick,
    required this.onUnstage,
  });

  final List<BulkStagedSet> sets;
  final VoidCallback onPick;
  final ValueChanged<String> onUnstage;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Padding(
      // The membership editor's side padding, so the row lines up with it.
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              key: const ValueKey('bulk-remove-set'),
              onPressed: onPick,
              icon: const Icon(Icons.folder_off, size: 18),
              label: Text(l10n.diveLog_edit_removeSet),
            ),
          ),
          if (sets.isNotEmpty) ...[
            Text(
              l10n.diveLog_bulkEdit_setsToRemove,
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final set in sets)
                  InputChip(
                    key: ValueKey('bulk-staged-set-${set.id}'),
                    avatar: const Icon(Icons.folder_special, size: 18),
                    label: Text(set.name),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    deleteIconColor: theme.colorScheme.error,
                    onDeleted: () => onUnstage(set.id),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
