import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/service_severity_colors.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The number of pieces of gear behind [alerts]. The provider yields one
/// entry per blocking CLOCK; the label counts ITEMS, so this collapses to
/// distinct equipment ids (hydro + VIP on one cylinder is still one item to
/// bring to the shop).
int tripServiceAlertItemCount(List<DueClock> alerts) =>
    alerts.map((a) => a.item.id).toSet().length;

/// Whether any blocking clock is already overdue rather than merely coming
/// due before the trip ends.
bool tripServiceAlertsAnyOverdue(List<DueClock> alerts) =>
    alerts.any((a) => a.status.severity == ServiceClockSeverity.overdue);

/// The pre-trip gear nag's detail: one row per blocking clock, naming the
/// item and when it falls due. Tapping a row opens the item.
class TripServiceAlertList extends ConsumerWidget {
  final List<DueClock> alerts;

  const TripServiceAlertList({super.key, required this.alerts});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = UnitFormatter(ref.watch(settingsProvider));
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final alert in alerts)
          Semantics(
            button: true,
            label: alert.item.name,
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.circle,
                size: 12,
                color: serviceSeverityDotColor(context, alert.status.severity),
              ),
              title: Text(alert.item.name),
              subtitle: Text(_alertSubtitle(context, units, alert.status)),
              onTap: () => context.push('/equipment/${alert.item.id}'),
            ),
          ),
      ],
    );
  }

  String _alertSubtitle(
    BuildContext context,
    UnitFormatter units,
    ServiceClockStatus status,
  ) {
    // Key off severity, not now-vs-dueDate: a clock overdue on dives/hours can
    // still have a future (or null) date trigger, and must read as "overdue".
    // Non-overdue alerts only reach the list with a concrete future dueDate
    // (see tripServiceAlertsProvider), so "due before {date}" is always safe.
    final dueDate = status.dueDate;
    if (status.severity == ServiceClockSeverity.overdue || dueDate == null) {
      return context.l10n.equipment_service_overdue(status.kind.name);
    }
    return context.l10n.trips_serviceAlert_dueBefore(
      status.kind.name,
      units.formatDate(dueDate),
    );
  }
}
