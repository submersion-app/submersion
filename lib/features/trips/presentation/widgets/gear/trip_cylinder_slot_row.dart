import 'package:flutter/material.dart';

import 'package:submersion/core/icons/mdi_icons.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_state.dart';
import 'package:submersion/features/trips/presentation/helpers/trip_cylinder_display.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One cylinder slot on the Gear tab (#2845). Before departure: the label,
/// its specs, and whether it is rental or the diver's own. From the first
/// day: the status dot, bottle, mix and pressure, as the board shows them.
class TripCylinderSlotRow extends StatelessWidget {
  final TripCylinderState state;
  final bool started;
  final UnitFormatter units;
  final VoidCallback onTap;

  const TripCylinderSlotRow({
    super.key,
    required this.state,
    required this.started,
    required this.units,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final c = state.cylinder;
    final origin = c.equipmentId == null
        ? l10n.trips_gear_slot_rental
        : l10n.trips_gear_slot_own;

    if (started) {
      final mix = state.mix;
      final pressure = state.pressure;
      return ListTile(
        key: Key('trip-gear-slot-${c.id}'),
        leading: Icon(
          Icons.circle,
          size: 14,
          color: tripCylinderStatusColor(theme.colorScheme, state.status),
          semanticLabel: tripCylinderStatusLabel(l10n, state.status),
        ),
        title: Text(
          '${state.bottleLabel} · '
          '${mix == null ? '--' : tripCylinderMixLabel(l10n, mix)} · '
          '${pressure == null ? '--' : units.formatPressure(pressure)}',
        ),
        subtitle: Text('${c.label} · $origin'),
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
      subtitle: Text([...specs, origin].join(' · ')),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
