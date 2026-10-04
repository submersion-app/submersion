import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/icons/mdi_icons.dart';
import 'package:submersion/core/theme/status_colors.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/service_severity_colors.dart';
import 'package:submersion/features/trips/presentation/widgets/gear/trip_gear_alert_sheet.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_service_alert_list.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/tile_subtitle_action.dart';

/// An owned tank packed for the trip with no slot on its board (#2873): the
/// old Use set packed tanks as gear. It is listed under Cylinders with its
/// specs, a tinted "not on the board" line and an action to put it on the
/// board, where it gets a fill state and counts toward the plan. Its service
/// clocks read on it as on any packed item. It can still be unpacked;
/// tapping the rest of the row opens the item.
class TripUnslottedTankRow extends StatefulWidget {
  final EquipmentItem item;
  final UnitFormatter units;

  /// Every blocking clock on the tank, most pressing first: the first is
  /// the tinted line, the sheet lists them all.
  final List<DueClock> alerts;
  final Future<void> Function() onPutOnBoard;
  final Future<void> Function() onUnpack;

  const TripUnslottedTankRow({
    super.key,
    required this.item,
    required this.units,
    this.alerts = const [],
    required this.onPutOnBoard,
    required this.onUnpack,
  });

  @override
  State<TripUnslottedTankRow> createState() => _TripUnslottedTankRowState();
}

class _TripUnslottedTankRowState extends State<TripUnslottedTankRow> {
  /// True while the slot is written: a second tap would add a second slot
  /// for the same tank before the board's refresh removes this row.
  bool _putting = false;

  Future<void> _put() async {
    setState(() => _putting = true);
    try {
      await widget.onPutOnBoard();
    } finally {
      if (mounted) setState(() => _putting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final units = widget.units;
    final alerts = widget.alerts;
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
          if (alerts.isNotEmpty)
            InkWell(
              key: Key('trip-gear-alert-${item.id}'),
              onTap: () =>
                  showTripGearAlertSheet(context, item: item, alerts: alerts),
              child: Text(
                tripServiceAlertSubtitle(context, units, alerts.first.status),
                style: TextStyle(
                  color: serviceSeveritySwatch(
                    status,
                    alerts.first.status.severity,
                  )?.accent,
                ),
              ),
            ),
          Text(
            l10n.trips_gear_tank_notOnBoard,
            style: TextStyle(color: status.warn.accent),
          ),
          TileSubtitleAction(
            actionKey: Key('trip-gear-putOnBoard-${item.id}'),
            label: l10n.trips_gear_tank_putOnBoard,
            onPressed: _putting ? null : _put,
          ),
        ],
      ),
      trailing: PopupMenuButton<String>(
        key: Key('trip-gear-menu-${item.id}'),
        onSelected: (_) => widget.onUnpack(),
        itemBuilder: (_) => [
          PopupMenuItem(value: 'unpack', child: Text(l10n.trips_gear_remove)),
        ],
      ),
      onTap: () => context.push('/equipment/${item.id}'),
    );
  }
}
