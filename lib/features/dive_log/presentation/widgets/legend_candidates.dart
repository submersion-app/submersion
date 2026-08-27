import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One toggle that competes for space in the inline legend row.
///
/// [priority] is the canonical display position (lower renders further left).
/// Active candidates are admitted before inactive ones regardless of
/// priority, but the admitted set always renders in priority order so a
/// toggle never changes position when clicked.
@immutable
class LegendCandidate {
  final String id;
  final String label;
  final Color color;
  final bool isActive;
  final int priority;
  final VoidCallback onTap;

  const LegendCandidate({
    required this.id,
    required this.label,
    required this.color,
    required this.isActive,
    required this.priority,
    required this.onTap,
  });
}

/// Selects which candidates fit the inline legend row.
///
/// Admission order is active-first (each group in priority order); admission
/// stops at the first candidate that does not fit, keeping the visible set a
/// stable prefix rather than a width-dependent patchwork. The returned list
/// is sorted back into priority order for display.
List<LegendCandidate> selectInlineCandidates({
  required List<LegendCandidate> candidates,
  required double availableWidth,
  required double Function(LegendCandidate candidate) itemWidth,
}) {
  final byPriority = [...candidates]
    ..sort((a, b) => a.priority.compareTo(b.priority));
  final admissionOrder = [
    ...byPriority.where((c) => c.isActive),
    ...byPriority.where((c) => !c.isActive),
  ];

  final admitted = <LegendCandidate>[];
  var used = 0.0;
  for (final candidate in admissionOrder) {
    final width = itemWidth(candidate);
    if (used + width > availableWidth) break;
    used += width;
    admitted.add(candidate);
  }
  admitted.sort((a, b) => a.priority.compareTo(b.priority));
  return admitted;
}

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
