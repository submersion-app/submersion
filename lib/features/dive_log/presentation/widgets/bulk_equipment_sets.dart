import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/domain/entities/bulk_edit_request.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/equipment_set_picker_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/bulk_edit/bulk_membership_editor.dart';

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

/// The gear a bulk edit adds: the [delta]'s adds, and every item a set
/// switched on ([setOf]) that the diver has not switched off again. An item
/// already on every dive makes no add of its own, but a set removed in the
/// same edit may take it off first, so the set that was used puts it back
/// (#4284, the "Remove Set A, Use Set B" swap).
List<String> equipmentAddIds(
  MembershipDelta delta,
  Map<String, String> setOf,
) => [
  ...delta.addIds,
  for (final id in setOf.keys)
    if (!delta.addIds.contains(id) && !delta.removeIds.contains(id)) id,
];

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

/// [staged] with [set] added, unless it is already there.
List<BulkStagedSet> withStagedSet(
  List<BulkStagedSet> staged,
  BulkStagedSet set,
) => staged.any((s) => s.id == set.id) ? staged : [...staged, set];

/// The set picker, titled for taking a set off: the set picked, or null
/// when the diver backs out.
Future<BulkStagedSet?> pickEquipmentSetToRemove(BuildContext context) =>
    showModalBottomSheet<BulkStagedSet>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => EquipmentSetPickerSheet(
          scrollController: scrollController,
          title: context.l10n.diveLog_bulkEdit_removeSetTitle,
          onSetSelected: (set, _) =>
              Navigator.of(context).pop((id: set.id, name: set.name)),
        ),
      ),
    );

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
