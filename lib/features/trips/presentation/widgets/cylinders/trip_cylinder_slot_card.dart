import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  final used = await repo.countLinkedDives(cylinder.id);
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
  await repo.deleteCylinder(cylinder.id);
  return true;
}

enum _SlotAction { fill, adjust, edit, delete }

/// One slot on the board: its status dot and word, mix, pressure, the
/// bottle now in it, its size, the last thing that happened to it and how
/// many dives used it, with a menu to fill, adjust, edit or delete it.
class TripCylinderSlotCard extends ConsumerWidget {
  final TripCylinderState state;

  /// Every slot on the trip, so a fill started here can default its
  /// station from the trip's last fill.
  final List<TripCylinderState> allStates;
  final Map<String, String> centerNames;

  const TripCylinderSlotCard({
    super.key,
    required this.state,
    required this.allStates,
    required this.centerNames,
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
    final mix = state.mix == null
        ? '--'
        : tripCylinderMixLabel(l10n, state.mix!);
    final pressure = state.pressure == null
        ? '--'
        : units.formatPressure(state.pressure);
    final status = tripCylinderStatusLabel(l10n, state.status);
    final last = tripCylinderLastItemText(
      l10n,
      units,
      state,
      centerNames: centerNames,
    );
    final small = theme.textTheme.bodySmall;
    return Card(
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
            Text('$mix · $pressure · $status'),
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
        trailing: PopupMenuButton<_SlotAction>(
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
              value: _SlotAction.edit,
              child: Text(l10n.common_action_edit),
            ),
            PopupMenuItem(
              value: _SlotAction.delete,
              child: Text(l10n.common_action_delete),
            ),
          ],
        ),
      ),
    );
  }
}
