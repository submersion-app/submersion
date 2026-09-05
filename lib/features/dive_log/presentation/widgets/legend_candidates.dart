import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
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

/// Display label for a tank: its name (or "Tank N") plus the gas mix name.
String tankLegendLabel(
  BuildContext context,
  DiveTank tank, {
  required int fallbackIndex,
}) {
  final tankTitle = tank.name?.trim().isNotEmpty == true
      ? tank.name!.trim()
      : context.l10n.diveLog_tank_title(fallbackIndex);
  return '$tankTitle (${tank.gasMix.name})';
}
