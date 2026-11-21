import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/editing/buddy_card_ids.dart';
import 'package:submersion/features/buddies/presentation/editing/buddy_gear_sitting.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/domain/services/gear_with_buddy.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_location_list_page.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_location_picker_sheet.dart';
import 'package:submersion/features/equipment/presentation/widgets/lend_gear_flow.dart';
import 'package:submersion/features/equipment/presentation/widgets/return_equipment_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_header.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_pencil.dart';
import 'package:submersion/shared/widgets/tile_subtitle_action.dart';

/// The diver's gear this buddy has (issue #3790): anything whose current place
/// links here, loaned or in everyday family use. Builds nothing, its spacing
/// included, when there is none, so most buddies show no trace of it.
///
/// It offers nothing outside the open Gear card (issue #4527, phase 3); in
/// the page's sitting ([editing]) Lend gear, All returned and Returned are
/// asked about at once and held until Save, and the rows show the gear as
/// the sitting holds it.
class BuddyGearSection extends ConsumerWidget {
  final Buddy buddy;

  /// The sitting its moves are held in: it is the Gear card's editor,
  /// drawn inside the open card.
  final EditSession<Buddy>? editing;

  /// The sitting whose rows a closed card shows, without offering its
  /// actions.
  final EditSession<Buddy>? shown;

  const BuddyGearSection({
    super.key,
    required this.buddy,
    this.editing,
    this.shown,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sitting = editing ?? shown;
    if (sitting == null) return _build(context, ref, null);
    return ListenableBuilder(
      listenable: sitting,
      builder: (context, _) => _build(context, ref, sitting),
    );
  }

  Future<void> _lend(
    BuildContext context,
    WidgetRef ref,
    EditSession<Buddy> editing,
    List<BuddyGearRow> rows,
  ) async {
    final held = heldBuddyGearMoves(editing);
    final lend = await planLendGear(
      context,
      ref,
      buddy,
      lent: {
        for (final row in rows)
          if (row.heldIndex != null) row.gear.item.id,
      },
      // A return's parts too: they leave with their items at Save.
      returned: {
        for (final move in held)
          if (move.returned case final returned?) ...[
            ...returned.plan.items.keys,
            ...returned.plan.partIds,
          ],
      },
    );
    if (lend != null && !editing.isDisposed) holdBuddyLend(editing, lend);
  }

  Future<void> _return(
    BuildContext context,
    WidgetRef ref,
    EditSession<Buddy> editing,
    List<BuddyGearRow> rows,
  ) async {
    final items = [for (final row in rows) row.gear.item];
    final returned = await planEquipmentReturn(
      context,
      ref,
      items: items,
      buddyId: buddy.id,
    );
    if (returned != null && !editing.isDisposed) {
      holdBuddyReturn(editing, returned);
    }
  }

  /// What a row's Returned does: nothing outside the open card; for an
  /// item a lend the sitting holds, takes that item out of the lend, and for
  /// one of its parts nothing, since a part follows its item; otherwise
  /// returns the item.
  VoidCallback? _onReturned(
    BuildContext context,
    WidgetRef ref,
    EditSession<Buddy>? editing,
    BuddyGearRow row,
  ) {
    if (editing == null) return null;
    final index = row.heldIndex;
    if (index != null) {
      final id = row.gear.item.id;
      final lend = heldBuddyGearMoves(editing)[index].lend;
      if (lend == null || !lend.items.any((i) => i.id == id)) return null;
      final moves = ref.read(equipmentLocationMoveRepositoryProvider);
      return () =>
          releaseBuddyLendItem(editing, index, id, partsOf: moves.partsOf);
    }
    return () => _return(context, ref, editing, [row]);
  }

  Widget _build(
    BuildContext context,
    WidgetRef ref,
    EditSession<Buddy>? sitting,
  ) {
    final l10n = context.l10n;
    // Only the open card's sitting takes moves.
    final editing = this.editing;
    final current =
        ref.watch(currentEquipmentLocationsProvider).value ??
        const <String, EquipmentLocation>{};
    final items = itemsAtPlaces(ref);
    final stored = gearWithBuddy(buddy.id, items, current);
    final rows = sitting == null
        ? [for (final gear in stored) (gear: gear, heldIndex: null)]
        : buddyGearInSitting(sitting, stored, items: items);
    // In the open card it is shown whatever it holds: Lend starts there.
    if (rows.isEmpty && editing == null) return const SizedBox.shrink();
    // Lends the sitting holds to somewhere other than this buddy: listed in
    // the open card only, so they can be taken back.
    final elsewhere = editing == null
        ? const <(int, HeldLend)>[]
        : [
            for (final (i, move) in heldBuddyGearMoves(editing).indexed)
              if (move.lend case final lend?)
                if (lend.pick is! BuddyPick ||
                    (lend.pick as BuddyPick).buddy.id != buddy.id)
                  (i, lend),
          ];
    // The rows held for return are the stored ones still listed.
    final returnable = [
      for (final row in rows)
        if (row.heldIndex == null) row,
    ];

    // Only worth saying when it tells the rows apart.
    final namePlaces = rows.map((r) => r.gear.place.id).toSet().length > 1;
    final title = l10n.buddies_gear_title(buddy.name);

    final content = <Widget>[
      if (editing != null)
        Wrap(
          spacing: 8,
          children: [
            TextButton.icon(
              key: const ValueKey('buddy_gear_lend'),
              icon: const Icon(Icons.add),
              label: Text(l10n.buddies_action_lendGear),
              onPressed: () => _lend(context, ref, editing, rows),
            ),
            if (returnable.length > 1)
              TextButton.icon(
                key: const ValueKey('buddy_gear_all_returned'),
                icon: const Icon(Icons.keyboard_return),
                label: Text(l10n.buddies_gear_allReturned),
                onPressed: () => _return(context, ref, editing, returnable),
              ),
          ],
        ),
      for (final row in rows)
        _GearRow(
          row: row.gear,
          namePlace: namePlaces,
          held: row.heldIndex != null,
          // This section's context, not the row's: a returned item
          // leaves the list as its move saves, and a prompt shown
          // from a context that has gone is silently a no.
          onReturned: _onReturned(context, ref, editing, row),
        ),
      for (final (index, lend) in elsewhere)
        ListTile(
          key: ValueKey('buddy_gear_elsewhere_$index'),
          contentPadding: EdgeInsets.zero,
          leading: const RecordChangedDot(),
          title: Text([for (final item in lend.items) item.name].join(', ')),
          subtitle: Text(switch (lend.pick) {
            PlacePick(:final location) => location.name,
            BuddyPick(:final buddy) => buddy.name,
            NoLocationPick() => l10n.equipment_location_noLocation,
          }),
          trailing: IconButton(
            icon: const Icon(Icons.close),
            tooltip: l10n.common_action_cancel,
            onPressed: () => releaseBuddyGearMove(editing!, index),
          ),
        ),
    ];
    // The open card draws its own frame and title.
    if (editing != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: content,
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  RecordCardPencil(
                    cardTitle: BuddyCardId.gear.localizedDisplayName(l10n),
                  ),
                ],
              ),
              ...content,
            ],
          ),
        ),
      ),
    );
  }
}

class _GearRow extends ConsumerWidget {
  const _GearRow({
    required this.row,
    required this.namePlace,
    required this.onReturned,
    this.held = false,
  });

  final GearWithBuddy row;
  final bool namePlace;

  /// Returned; for a lend the sitting holds, takes it back. Null offers
  /// nothing.
  final VoidCallback? onReturned;

  /// Lent in the sitting, not yet saved.
  final bool held;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final units = ref.watch(unitFormatterProvider);
    final item = row.item;
    final moves =
        ref.watch(equipmentLocationMovesProvider(item.id)).value ?? const [];
    return ListTile(
      key: ValueKey('buddy_gear_${item.id}'),
      contentPadding: EdgeInsets.zero,
      title: Row(
        children: [
          Flexible(child: Text(item.name)),
          if (held) ...[const SizedBox(width: 6), const RecordChangedDot()],
        ],
      ),
      subtitle: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [
              item.type.localizedName(l10n),
              if (moves.isNotEmpty)
                l10n.equipment_location_since(
                  units.formatDate(moves.first.movedAt),
                ),
              // Family gear stays Active, so only a real loan is labelled.
              if (item.status == EquipmentStatus.loaned)
                item.status.localizedName(l10n),
              if (namePlace) row.place.name,
            ].join(' · '),
          ),
          if (onReturned case final onPressed?)
            TileSubtitleAction(
              actionKey: ValueKey('buddy_gear_returned_${item.id}'),
              // A lend the sitting holds is taken back, not returned.
              label: held
                  ? l10n.common_action_cancel
                  : l10n.buddies_gear_returned,
              semanticsLabel: held
                  ? '${l10n.common_action_cancel}: ${item.name}'
                  : '${l10n.buddies_gear_returned}: ${item.name}',
              onPressed: onPressed,
            ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/equipment/${item.id}'),
    );
  }
}
