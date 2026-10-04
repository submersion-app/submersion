import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_state.dart';
import 'package:submersion/features/trips/presentation/helpers/trip_cylinder_display.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/cylinders/trip_cylinder_adjust_sheet.dart';
import 'package:submersion/features/trips/presentation/widgets/cylinders/trip_cylinder_edit_sheet.dart';
import 'package:submersion/features/trips/presentation/widgets/cylinders/trip_cylinder_fill_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Asks before deleting [cylinder], naming how many dives used it, then
/// deletes it. The dives keep their tanks; only the link goes. Returns true
/// when the slot is gone.
Future<bool> confirmDeleteTripCylinder(
  BuildContext context,
  WidgetRef ref,
  TripCylinder cylinder,
) async {
  final l10n = context.l10n;
  final repo = ref.read(tripCylinderRepositoryProvider);
  final int used;
  try {
    used = await repo.countLinkedDives(cylinder.id);
  } catch (_) {
    if (context.mounted) showTripCylinderChangeFailed(context);
    return false;
  }
  if (!context.mounted) return false;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      content: Text(
        used == 0
            ? l10n.trips_cylinders_deleteConfirmUnused
            : l10n.trips_cylinders_deleteConfirmUsed(used),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.common_action_delete),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;
  try {
    await repo.deleteCylinder(cylinder.id);
    return true;
  } catch (_) {
    if (context.mounted) showTripCylinderChangeFailed(context);
    return false;
  }
}

enum _SlotAction { fill, adjust, logDive, edit, delete }

/// One slot on the board: its status dot and word, mix, pressure, the
/// bottle now in it, its size, the last thing that happened to it and how
/// many dives used it, with a menu to fill, adjust, edit or delete it.
class TripCylinderSlotCard extends ConsumerWidget {
  final TripCylinderState state;

  /// The card's place in a ReorderableListView, which then draws no drag
  /// handles of its own: they would sit on the list item's edge, past the
  /// card's margin (#2957). The card carries the drag instead, as a handle
  /// inside it on desktop and a long press on a phone.
  final int reorderIndex;

  /// Every slot on the trip, so a fill started here can default its
  /// station from the trip's last fill.
  final List<TripCylinderState> allStates;
  final Map<String, String> centerNames;

  const TripCylinderSlotCard({
    super.key,
    required this.state,
    required this.allStates,
    required this.centerNames,
    required this.reorderIndex,
  });

  Future<void> _act(BuildContext context, WidgetRef ref, _SlotAction action) {
    final c = state.cylinder;
    return switch (action) {
      _SlotAction.fill => showTripCylinderFillSheet(
        context,
        slots: allStates,
        preselected: {c.id},
      ),
      _SlotAction.adjust => showTripCylinderAdjustSheet(context, cylinder: c),
      // A new dive on this trip, its first tank breathing from this slot.
      _SlotAction.logDive => context.push(
        Uri(
          path: '/dives/new',
          queryParameters: {'tripId': c.tripId, 'tripCylinderId': c.id},
        ).toString(),
      ),
      _SlotAction.edit => showTripCylinderEditSheet(context, cylinder: c),
      _SlotAction.delete => confirmDeleteTripCylinder(context, ref, c),
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));
    final c = state.cylinder;
    final status = tripCylinderStatusLabel(l10n, state.status);
    final last = tripCylinderLastItemText(
      l10n,
      units,
      state,
      centerNames: centerNames,
    );
    final small = theme.textTheme.bodySmall;
    final handle = _dragsByHandle(theme.platform);
    final card = Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Icon(
          Icons.circle,
          size: 14,
          color: tripCylinderStatusColor(theme.colorScheme, state.status),
          semanticLabel: status,
        ),
        title: Text(c.label),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              [...tripCylinderGasParts(l10n, units, state), status].join(' · '),
            ),
            if (state.bottleLabel != c.label)
              Text(l10n.trips_cylinders_bottle(state.bottleLabel)),
            if (c.volume != null)
              Text(
                units.formatTankVolume(c.volume, c.workingPressure),
                style: small,
              ),
            if (last != null) Text(last, style: small),
            if (state.linkedDiveCount > 0)
              Text(
                l10n.trips_cylinders_linkedDives(state.linkedDiveCount),
                style: small,
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _menu(context, ref),
            if (handle)
              ReorderableDragStartListener(
                key: Key('slot-drag-${c.id}'),
                index: reorderIndex,
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.drag_handle),
                ),
              ),
          ],
        ),
      ),
    );
    if (handle) return card;
    return ReorderableDelayedDragStartListener(
      index: reorderIndex,
      child: card,
    );
  }

  /// Desktop drags by a handle and a phone by a long press, as
  /// ReorderableListView's own handles do.
  static bool _dragsByHandle(TargetPlatform platform) => switch (platform) {
    TargetPlatform.linux ||
    TargetPlatform.macOS ||
    TargetPlatform.windows => true,
    TargetPlatform.android ||
    TargetPlatform.fuchsia ||
    TargetPlatform.iOS => false,
  };

  Widget _menu(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final c = state.cylinder;
    return PopupMenuButton<_SlotAction>(
      key: Key('slot-menu-${c.id}'),
      onSelected: (action) => _act(context, ref, action),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: _SlotAction.fill,
          child: Text(l10n.trips_cylinders_action_fill),
        ),
        PopupMenuItem(
          value: _SlotAction.adjust,
          child: Text(l10n.trips_cylinders_action_adjust),
        ),
        PopupMenuItem(
          value: _SlotAction.logDive,
          child: Text(l10n.trips_cylinders_action_logDive),
        ),
        PopupMenuItem(
          value: _SlotAction.edit,
          child: Text(l10n.common_action_edit),
        ),
        PopupMenuItem(
          value: _SlotAction.delete,
          child: Text(l10n.common_action_delete),
        ),
      ],
    );
  }
}
