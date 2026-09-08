import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Formats the "Due {date}" / "Overdue since {date}" / "N of M dives left" /
/// "N of M hours left" trigger line for one service clock, joining whichever
/// triggers are configured. Shared by [ServiceClocksCard] (live equipment
/// clocks) and the pre-dive checklist item tile (live and frozen overdue
/// summaries), so both read the exact same wording.
String formatServiceTriggerText(
  BuildContext context, {
  required UnitFormatter units,
  required DateTime now,
  DateTime? dueDate,
  int? divesSinceAnchor,
  int? divesRemaining,
  double? hoursSinceAnchor,
  double? hoursRemaining,
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
  if (divesRemaining != null && divesSinceAnchor != null) {
    parts.add(
      l10n.equipment_serviceClocks_divesLeft(
        divesRemaining < 0 ? 0 : divesRemaining,
        divesSinceAnchor + divesRemaining,
      ),
    );
  }
  if (hoursRemaining != null && hoursSinceAnchor != null) {
    parts.add(
      l10n.equipment_serviceClocks_hoursLeft(
        (hoursRemaining < 0 ? 0.0 : hoursRemaining).toStringAsFixed(1),
        (hoursSinceAnchor + hoursRemaining).toStringAsFixed(1),
      ),
    );
  }
  return parts.join(' · ');
}
