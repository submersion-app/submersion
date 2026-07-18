import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A compact single-line banner showing alerts and reminders.
class AlertsCard extends ConsumerWidget {
  const AlertsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(dashboardAlertsProvider);

    return alertsAsync.when(
      data: (alerts) {
        if (!alerts.hasAlerts) {
          return const SizedBox.shrink();
        }
        return _CompactAlertsBanner(alerts: alerts);
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _CompactAlertsBanner extends StatelessWidget {
  final DashboardAlerts alerts;

  const _CompactAlertsBanner({required this.alerts});

  String _alertText(BuildContext context) {
    if (alerts.insuranceExpired) {
      return context.l10n.dashboard_alerts_insuranceExpired;
    }
    if (alerts.insuranceExpiringSoon) {
      return context.l10n.dashboard_alerts_insuranceExpiringSoon;
    }
    final clock = alerts.serviceClocksDue.first;
    final isOverdue = clock.status.severity == ServiceClockSeverity.overdue;
    return isOverdue
        ? context.l10n.dashboard_alerts_clockOverdue(
            clock.item.name,
            clock.status.kind.name,
          )
        : context.l10n.dashboard_alerts_clockDue(
            clock.item.name,
            clock.status.kind.name,
          );
  }

  void _onTap(BuildContext context) {
    if (alerts.alertCount == 1) {
      if (alerts.insuranceExpired || alerts.insuranceExpiringSoon) {
        context.go('/settings');
        return;
      }
      if (alerts.serviceClocksDue.isNotEmpty) {
        final clock = alerts.serviceClocksDue.first;
        context.push('/equipment/${clock.item.id}');
        return;
      }
    }
    context.go('/settings');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final alertText = _alertText(context);

    return GestureDetector(
      onTap: () => _onTap(context),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.errorContainer.withValues(alpha: 0.3),
          border: Border.all(color: colorScheme.error.withValues(alpha: 0.2)),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.warning_amber, color: colorScheme.error, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                alertText,
                style: theme.textTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colorScheme.error,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${alerts.alertCount}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onError,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              size: 16,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
