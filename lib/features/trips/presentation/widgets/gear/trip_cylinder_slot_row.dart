import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/icons/mdi_icons.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_state.dart';
import 'package:submersion/features/trips/presentation/widgets/gear/trip_gear_alert_sheet.dart';
import 'package:submersion/features/trips/presentation/helpers/trip_cylinder_display.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One cylinder slot on the Gear tab (#2845). Before departure: the label,
/// its specs, and whether it is rental or the diver's own. From the first
/// day: the status dot, bottle, mix and pressure, as the board shows them.
/// An owned cylinder's service clocks (a hydro or visual falling due) add a
/// tinted line that opens their detail, as a packed item's do. An owned
/// slot names its item, since its label is often the tank's mark.
class TripCylinderSlotRow extends ConsumerWidget {
  final TripCylinderState state;
  final bool started;
  final UnitFormatter units;
  final VoidCallback onTap;

  /// The linked item's blocking clocks, most pressing first; empty for a
  /// rental slot or a cylinder with nothing due.
  final List<DueClock> alerts;

  const TripCylinderSlotRow({
    super.key,
    required this.state,
    required this.started,
    required this.units,
    required this.onTap,
    this.alerts = const [],
  });

  /// The tinted, tappable line for the slot's most pressing clock, or null.
  Widget? _alertLine(BuildContext context) =>
      alerts.isEmpty ? null : TripGearAlertLine(alerts: alerts, units: units);

  /// [text] with the alert line under it when there is one.
  Widget _subtitle(BuildContext context, String text) {
    final line = _alertLine(context);
    if (line == null) return Text(text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [Text(text), line],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final c = state.cylinder;
    final equipmentId = c.equipmentId;
    // The item's name, unless it only repeats the label; "My equipment"
    // while it loads or when the item is gone.
    final itemName = equipmentId == null
        ? null
        : ref.watch(equipmentItemProvider(equipmentId)).value?.name;
    final origin = equipmentId == null
        ? l10n.trips_gear_slot_rental
        : (itemName == null || itemName == c.label
              ? l10n.trips_gear_slot_own
              : itemName);

    if (started) {
      final status = tripCylinderStatusLabel(l10n, state.status);
      return ListTile(
        key: Key('trip-gear-slot-${c.id}'),
        leading: Icon(
          Icons.circle,
          size: 14,
          color: tripCylinderStatusColor(theme.colorScheme, state.status),
          semanticLabel: status,
        ),
        // An unfilled slot has no mix or pressure to show, and its grey dot
        // says little, so it names its status instead.
        title: Text(
          [
            state.bottleLabel,
            ...tripCylinderGasParts(l10n, units, state),
            if (state.status == TripCylinderStatus.unknown) status,
          ].join(' · '),
        ),
        subtitle: _subtitle(context, '${c.label} · $origin'),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      );
    }

    final specs = [
      // A cylinder's size: litres of tank in metric, rated gas in imperial,
      // as the board shows it.
      if (c.volume != null) units.formatTankVolume(c.volume, c.workingPressure),
      if (c.workingPressure != null) units.formatPressure(c.workingPressure),
    ];
    return ListTile(
      key: Key('trip-gear-slot-${c.id}'),
      leading: Icon(MdiIcons.divingScubaTank, color: theme.colorScheme.primary),
      title: Text(c.label),
      subtitle: _subtitle(context, [...specs, origin].join(' · ')),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
