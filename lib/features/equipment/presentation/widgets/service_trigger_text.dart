import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/presentation/utils/exposure_unit_display.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Formats the "Due {date}" / "Overdue since {date}" / "N of M dives left" /
/// "N of M hours left" trigger line for one service clock, joining whichever
/// triggers are configured. Shared by [ServiceClocksCard] (live equipment
/// clocks) and the pre-dive checklist item tile (live and frozen overdue
/// summaries), so both read the exact same wording.
///
/// The legacy dives and hours arguments and [usageByUnit] say the same
/// thing; they fold together so a caller passing either form renders one
/// line per unit, in [ExposureUnit] order.
String formatServiceTriggerText(
  BuildContext context, {
  required UnitFormatter units,
  required DateTime now,
  DateTime? dueDate,
  int? divesSinceAnchor,
  int? divesRemaining,
  double? hoursSinceAnchor,
  double? hoursRemaining,
  Map<ExposureUnit, ClockUsage> usageByUnit = const {},
}) {
  final l10n = context.l10n;
  final parts = <String>[];
  if (dueDate != null) {
    final formatted = units.formatDate(dueDate);
    parts.add(
      // Strict isAfter: at the exact due instant (now == dueDate) the engine
      // treats the date trigger as due-soon, not overdue, so render "Due
      // {date}" until now is strictly past dueDate. Matches the engine's
      // now.isAfter(dueDate) boundary.
      now.isAfter(dueDate)
          ? l10n.equipment_serviceClocks_overdueSince(formatted)
          : l10n.equipment_serviceClocks_dueOn(formatted),
    );
  }
  final usage = <ExposureUnit, ClockUsage>{...usageByUnit};
  if (divesRemaining != null && divesSinceAnchor != null) {
    usage.putIfAbsent(
      ExposureUnit.dives,
      () => ClockUsage(
        interval: (divesSinceAnchor + divesRemaining).toDouble(),
        since: divesSinceAnchor.toDouble(),
      ),
    );
  }
  if (hoursRemaining != null && hoursSinceAnchor != null) {
    usage.putIfAbsent(
      ExposureUnit.hours,
      () => ClockUsage(
        interval: hoursSinceAnchor + hoursRemaining,
        since: hoursSinceAnchor,
      ),
    );
  }
  for (final unit in ExposureUnit.values) {
    final u = usage[unit];
    if (u == null || unit == ExposureUnit.days) continue;
    final remaining = u.remaining < 0 ? 0.0 : u.remaining;
    parts.add(
      unit.isFractional
          ? unit.leftText(
              l10n,
              remaining: remaining.toStringAsFixed(1),
              total: u.interval.toStringAsFixed(1),
            )
          : unit.leftText(
              l10n,
              remaining: remaining.round().toString(),
              total: u.interval.round().toString(),
            ),
    );
  }
  return parts.join(' · ');
}
