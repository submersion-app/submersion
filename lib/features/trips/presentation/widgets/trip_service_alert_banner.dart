import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Pre-trip gear nag: shows when an upcoming (or in-progress) trip has gear
/// whose service falls due before the trip ends. Tapping opens a sheet
/// listing each blocking clock. Renders nothing otherwise.
class TripServiceAlertBanner extends ConsumerWidget {
  final Trip trip;

  const TripServiceAlertBanner({super.key, required this.trip});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!trip.isUpcoming && !trip.isInProgress) {
      return const SizedBox.shrink();
    }
    final alertsAsync = ref.watch(tripServiceAlertsProvider(trip.id));
    final alerts = alertsAsync.value ?? const <DueClock>[];
    if (alerts.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    // The provider yields one entry per blocking CLOCK; the label counts
    // ITEMS, so collapse to distinct equipment ids (hydro + VIP on one
    // cylinder is still one item to bring to the shop).
    final itemCount = alerts.map((a) => a.item.id).toSet().length;
    final anyOverdue = alerts.any(
      (a) => a.status.severity == ServiceClockSeverity.overdue,
    );
    final background = anyOverdue
        ? scheme.errorContainer
        : scheme.tertiaryContainer;
    final foreground = anyOverdue
        ? scheme.onErrorContainer
        : scheme.onTertiaryContainer;

    return Semantics(
      button: true,
      label: context.l10n.trips_serviceAlert_count(itemCount),
      child: InkWell(
        onTap: () => _showAlertSheet(context, alerts),
        child: Container(
          width: double.infinity,
          color: background,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.build, size: 16, color: foreground),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.l10n.trips_serviceAlert_count(itemCount),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: foreground),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.chevron_right, size: 16, color: foreground),
            ],
          ),
        ),
      ),
    );
  }

  void _showAlertSheet(BuildContext context, List<DueClock> alerts) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final alert in alerts)
                Semantics(
                  button: true,
                  label: alert.item.name,
                  child: ListTile(
                    leading: Icon(
                      Icons.circle,
                      size: 12,
                      color:
                          alert.status.severity == ServiceClockSeverity.overdue
                          ? Theme.of(sheetContext).colorScheme.error
                          : Theme.of(sheetContext).colorScheme.tertiary,
                    ),
                    title: Text(alert.item.name),
                    subtitle: Text(_alertSubtitle(sheetContext, alert.status)),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      context.push('/equipment/${alert.item.id}');
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _alertSubtitle(BuildContext context, ServiceClockStatus status) {
    // Key off severity, not now-vs-dueDate: a clock overdue on dives/hours can
    // still have a future (or null) date trigger, and must read as "overdue".
    // Non-overdue alerts only reach the banner with a concrete future dueDate
    // (see tripServiceAlertsProvider), so "due before {date}" is always safe.
    final dueDate = status.dueDate;
    if (status.severity == ServiceClockSeverity.overdue || dueDate == null) {
      return context.l10n.trips_serviceAlert_overdue(status.kind.name);
    }
    return context.l10n.trips_serviceAlert_dueBefore(
      status.kind.name,
      MaterialLocalizations.of(context).formatShortDate(dueDate),
    );
  }
}
