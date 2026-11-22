import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/equipment/presentation/editing/gear_item_list_pending.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_pencil.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_location_picker_sheet.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_location_sitting.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location_move.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_location_display.dart';
import 'package:submersion/features/equipment/presentation/widgets/location_move_edit_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Where an item is now, a Move button, and its recent moves (the full log
/// behind "Show all"). Tapping a move edits or deletes it.
///
/// It offers nothing outside the open Location card (issue #4527, phase 3);
/// in the page's sitting ([editing]) a move and the edits of past moves are
/// held until Save, and a closed card shows what a sitting holds ([shown]).
class EquipmentLocationCard extends ConsumerStatefulWidget {
  const EquipmentLocationCard({
    super.key,
    required this.equipment,
    this.editing,
    this.shown,
  });

  final EquipmentItem equipment;

  /// The sitting moves are held in: the Location card's editor.
  final EditSession<EquipmentItem>? editing;

  /// The sitting whose moves a closed card shows.
  final EditSession<EquipmentItem>? shown;

  @override
  ConsumerState<EquipmentLocationCard> createState() =>
      _EquipmentLocationCardState();
}

class _EquipmentLocationCardState extends ConsumerState<EquipmentLocationCard> {
  static const _recentCount = 3;
  bool _showAll = false;

  /// Whether a tap may act: only in the open card.
  bool get _canAct => widget.editing != null;

  /// Whether a past move may be edited: in the open card, once the sitting
  /// has read the moves, so an edit has a list to go into.
  bool get _canEditPastMoves => switch (widget.editing) {
    final editing? => gearItemMovesList.current(editing) != null,
    null => false,
  };

  @override
  Widget build(BuildContext context) {
    final sitting = widget.editing ?? widget.shown;
    if (sitting == null) return _build(context, null);
    return ListenableBuilder(
      listenable: Listenable.merge([
        sitting,
        gearItemMovesList.changes(sitting),
      ]),
      builder: (context, _) => _build(context, sitting),
    );
  }

  Future<void> _move() async {
    final editing = widget.editing;
    if (editing == null) return;
    // The item as the sitting has it: a status changed in it decides what
    // the move offers.
    final move = await planGearItemMove(context, ref, editing.working);
    if (move != null) holdGearItemMove(editing, move);
  }

  /// [m] edited ([edited]) or deleted (null) in the sitting.
  void _holdEdit(EquipmentLocationMove m, EquipmentLocationMove? edited) {
    final editing = widget.editing!;
    final rows = gearItemMovesList.current(editing);
    if (rows == null) return;
    gearItemMovesList.set(editing, [
      for (final row in rows)
        if (row.id != m.id) row else ?edited,
    ]);
  }

  Widget _build(BuildContext context, EditSession<EquipmentItem>? sitting) {
    final l10n = context.l10n;
    final units = ref.watch(unitFormatterProvider);
    final stored =
        ref.watch(equipmentLocationMovesProvider(widget.equipment.id)).value ??
        const <EquipmentLocationMove>[];
    final moves = sitting == null
        ? stored
        : ([...gearItemMovesList.current(sitting) ?? stored]
            ..sort((a, b) => b.movedAt.compareTo(a.movedAt)));
    final held = sitting == null ? null : heldGearItemMove(sitting);
    final places =
        ref.watch(allEquipmentLocationsByIdProvider).value ??
        const <String, EquipmentLocation>{};
    final latest = moves.isEmpty ? null : moves.first;
    final current = held != null
        ? switch (held.pick) {
            PlacePick(:final location) => location,
            _ => null,
          }
        : latest == null
        ? null
        : places[latest.locationId];
    final buddyId = held == null ? current?.buddyId : null;
    final buddy = buddyId == null
        ? null
        : ref.watch(buddyByIdProvider(buddyId)).value;
    final heldBuddy = switch (held?.pick) {
      BuddyPick(:final buddy) => buddy,
      _ => null,
    };
    final movedAt = held?.plan.movedAt ?? latest?.movedAt;
    final note = held?.plan.note ?? latest?.note ?? '';
    final placed = current != null || heldBuddy != null;
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
                RecordCardPencil(cardTitle: l10n.equipment_location_card_title),
                if (_canAct)
                  TextButton.icon(
                    key: const ValueKey('equipment_location_move'),
                    icon: const Icon(Icons.move_down),
                    label: Text(l10n.equipment_location_moveButton),
                    onPressed: _move,
                  ),
              ],
            ),
            ListTile(
              key: const ValueKey('equipment_location_current'),
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                heldBuddy != null
                    ? EquipmentLocationKind.person.icon
                    : current?.kind.icon ?? Icons.location_off_outlined,
              ),
              title: Text(switch ((heldBuddy ?? buddy)?.name) {
                final name? => l10n.equipment_location_withBuddy(name),
                null => current?.name ?? l10n.equipment_location_none,
              }),
              subtitle: !placed || movedAt == null
                  ? null
                  : Text(
                      [
                        l10n.equipment_location_since(
                          units.formatDate(movedAt),
                        ),
                        if (note.isNotEmpty) note,
                      ].join('\n'),
                    ),
              trailing: buddy == null ? null : const Icon(Icons.chevron_right),
              onTap: buddy == null
                  ? null
                  : () => context.push('/buddies/${buddy.id}'),
            ),
            if (moves.isNotEmpty) const Divider(),
            if (widget.editing case final session?)
              ?gearItemListPending(gearItemMovesList, session),
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
      trailing: _canEditPastMoves
          ? const Icon(Icons.edit_outlined, size: 18)
          : null,
      onTap: !_canEditPastMoves
          ? null
          : () => showLocationMoveEditDialog(
              context,
              ref,
              m,
              onHold: (edited) => _holdEdit(m, edited),
            ),
    );
  }
}
