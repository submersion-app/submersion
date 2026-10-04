import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/icons/mdi_icons.dart';
import 'package:submersion/core/theme/status_colors.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/tile_subtitle_action.dart';

/// An owned tank packed for the trip with no slot on its board (#2873): the
/// old Use set packed tanks as gear. It is listed under Cylinders with its
/// specs, a tinted "not on the board" line and an action to put it on the
/// board, where it gets a fill state and counts toward the plan. It can
/// still be unpacked; tapping the rest of the row opens the item.
class TripUnslottedTankRow extends StatelessWidget {
  final EquipmentItem item;
  final UnitFormatter units;
  final Future<void> Function() onPutOnBoard;
  final Future<void> Function() onUnpack;

  const TripUnslottedTankRow({
    super.key,
    required this.item,
    required this.units,
    required this.onPutOnBoard,
    required this.onUnpack,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final status = StatusColors.of(context);
    // The tank's size as a slot shows it: litres in metric, rated gas in
    // imperial.
    final specs = [
      if (item.volumeL != null)
        units.formatTankVolume(item.volumeL, item.workingPressureBar),
      if (item.workingPressureBar != null)
        units.formatPressure(item.workingPressureBar),
    ];

    return ListTile(
      key: Key('trip-gear-tank-${item.id}'),
      leading: Icon(MdiIcons.divingScubaTank, color: theme.colorScheme.primary),
      title: Text(item.name),
      // The action sits under the subtitle, not in trailing, so a long
      // translation never squeezes the tank's name (#2717).
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (specs.isNotEmpty) Text(specs.join(' · ')),
          Text(
            l10n.trips_gear_tank_notOnBoard,
            style: TextStyle(color: status.warn.accent),
          ),
          TileSubtitleAction(
            actionKey: Key('trip-gear-putOnBoard-${item.id}'),
            label: l10n.trips_gear_tank_putOnBoard,
            onPressed: onPutOnBoard,
          ),
        ],
      ),
      trailing: PopupMenuButton<String>(
        key: Key('trip-gear-menu-${item.id}'),
        onSelected: (_) => onUnpack(),
        itemBuilder: (_) => [
          PopupMenuItem(value: 'unpack', child: Text(l10n.trips_gear_remove)),
        ],
      ),
      onTap: () => context.push('/equipment/${item.id}'),
    );
  }
}
