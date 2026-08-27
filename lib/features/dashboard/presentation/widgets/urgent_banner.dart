import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One line of the urgent banner and the place that fixes it.
typedef _UrgentLine = ({String label, String destination});

/// Compact banner listing only genuinely urgent items: overdue service
/// and expired insurance. Hidden otherwise. Each line is its own tap
/// target so it can open the specific item it names.
class UrgentBanner extends ConsumerWidget {
  const UrgentBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(dashboardAlertsProvider);
    final alerts = alertsAsync.valueOrNull;
    if (alerts == null) return const SizedBox.shrink();

    final overdue = alerts.serviceClocksDue
        .where((c) => c.status.severity == ServiceClockSeverity.overdue)
        .toList();
    final urgent = overdue.isNotEmpty || alerts.insuranceExpired;
    if (!urgent) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    // Cap the overdue-gear lines so a diver with many lapsed clocks doesn't
    // get a banner that dominates the dashboard; the overflow collapses to
    // a localized "+N more" line that opens the full gear list.
    const maxGearLines = 3;
    final shownOverdue = overdue.take(maxGearLines).toList();
    final hiddenCount = overdue.length - shownOverdue.length;
    // Each line carries its own destination: a line that names one item
    // opens that item, so the diver lands on the thing that needs attention
    // instead of an equipment list they then have to search. Only the
    // "+N more" overflow, which names nothing, falls back to the list.
    final lines = <_UrgentLine>[
      for (final clock in shownOverdue)
        (
          label: context.l10n.dashboard_gauges_gearOverdue(clock.item.name),
          destination: '/equipment/${clock.item.id}',
        ),
      if (hiddenCount > 0)
        (
          label: context.l10n.dashboard_serviceDue_more(hiddenCount),
          destination: '/equipment',
        ),
      if (alerts.insuranceExpired)
        (
          label: context.l10n.dashboard_gauges_insuranceExpired,
          destination: '/settings/diver-profile/insurance',
        ),
    ];
    return Card(
      margin: EdgeInsets.zero,
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded, color: scheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.dashboard_urgent_title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: scheme.onErrorContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  for (final line in lines)
                    _lineTile(context, line, scheme.onErrorContainer),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// One tappable banner line. Pushes rather than goes so Back returns to
  /// the dashboard the diver started from.
  Widget _lineTile(BuildContext context, _UrgentLine line, Color foreground) {
    return InkWell(
      onTap: () => context.push(line.destination),
      child: ConstrainedBox(
        // Keep the row at the minimum comfortable tap target; the label
        // alone is only a bodySmall line high.
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: [
            Expanded(
              child: Text(
                line.label,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: foreground),
              ),
            ),
            Icon(Icons.chevron_right, size: 16, color: foreground),
          ],
        ),
      ),
    );
  }
}
