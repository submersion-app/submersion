import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Sorts tank IDs by their tank's order; IDs without a matching tank go last.
List<String> sortTankIdsByOrder(
  Iterable<String> tankIds,
  List<DiveTank>? tanks,
) {
  int orderOf(String id) {
    if (tanks == null) return 999;
    for (final tank in tanks) {
      if (tank.id == id) return tank.order;
    }
    return 999;
  }

  final ids = tankIds.toList();
  ids.sort((a, b) => orderOf(a).compareTo(orderOf(b)));
  return ids;
}

const _tankFallbackColors = [
  Colors.orange,
  Colors.amber,
  Colors.green,
  Colors.cyan,
  Colors.purple,
  Colors.pink,
];

/// Color for a tank without gas mix info, cycling a fixed palette by index.
Color tankFallbackColor(int index) {
  return _tankFallbackColors[index % _tankFallbackColors.length];
}

/// Display label for the ceiling line, marked as calculated when it is drawn
/// against the computer's stops (issue #2552).
String ceilingLegendLabel(BuildContext context, {required bool calculated}) =>
    calculated
    ? context.l10n.diveLog_legend_label_ceilingCalculated
    : context.l10n.diveLog_legend_label_ceiling;

/// What an unnamed [tank], cylinder [number] (from 1), is called on the
/// profile: an Avelo Hydrotank by its role, so its pressure line, which
/// rises with the water pumped in, reads as the Hydrotank's (issue #4657);
/// any other cylinder by its number, "Tank 2".
String tankFallbackTitle(AppLocalizations l10n, DiveTank? tank, int number) =>
    tank?.role == TankRole.hydrotank
    ? l10n.enum_tankRole_hydrotank
    : l10n.diveLog_tank_title(number);

/// Display label for a tank: its name (or [tankFallbackTitle]) plus the gas
/// mix name.
String tankLegendLabel(
  BuildContext context,
  DiveTank tank, {
  required int fallbackIndex,
}) {
  final tankTitle = tank.name?.trim().isNotEmpty == true
      ? tank.name!.trim()
      : tankFallbackTitle(context.l10n, tank, fallbackIndex);
  return '$tankTitle (${tank.gasMix.name})';
}
