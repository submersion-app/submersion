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
          ? unit.usedAndLeftText(
              l10n,
              used: u.since.toStringAsFixed(1),
              remaining: remaining.toStringAsFixed(1),
              total: u.interval.toStringAsFixed(1),
            )
          : unit.usedAndLeftText(
              l10n,
              used: u.since.round().toString(),
              remaining: remaining.round().toString(),
              total: u.interval.round().toString(),
            ),
    );
  }
  return parts.join(' · ');
}

/// The single most urgent trigger for [status], in short form, for a
/// one-line chip or a tooltip where [formatServiceTriggerText]'s joined line
/// does not fit.
///
/// Every result carries its own preposition ("in 12d", "in 3 dives"),
/// because it composes into `equipment_service_dueRelative`, which supplies
/// none. That also keeps one idiom per locale rather than two.
///
/// A date trigger wins whenever the clock has one, since most clocks are
/// date-based and a day count is the form divers read fastest. With no date,
/// the usage unit with the least budget left wins, measured as a fraction of
/// its interval so units of different magnitudes compare; [ExposureUnit]
/// order breaks ties. Returns an empty string for a clock with no configured
/// trigger at all.
String formatServiceTriggerShort(
  BuildContext context, {
  required UnitFormatter units,
  required DateTime now,
  required ServiceClockStatus status,
}) {
  final l10n = context.l10n;
  final dueDate = status.dueDate;
  if (dueDate != null) {
    final days = dueDate.difference(now).inDays;
    return l10n.common_relativeTime_inDays(days < 0 ? 0 : days);
  }

  ExposureUnit? pick;
  double? bestRatio;
  for (final unit in ExposureUnit.values) {
    if (unit == ExposureUnit.days) continue;
    final usage = status.usageByUnit[unit];
    if (usage == null || usage.interval <= 0) continue;
    final ratio = usage.remaining / usage.interval;
    if (bestRatio == null || ratio < bestRatio) {
      bestRatio = ratio;
      pick = unit;
    }
  }
  if (pick == null) return '';

  final usage = status.usageByUnit[pick]!;
  // A spent clock is overdue, not negatively remaining; the same clamp
  // formatServiceTriggerText applies to its own usage lines.
  final remaining = usage.remaining < 0 ? 0.0 : usage.remaining;
  return pick.shortRemainingText(l10n, remaining);
}
