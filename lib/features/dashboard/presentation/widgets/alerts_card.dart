import 'dart:async';

import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/features/safety/presentation/utils/no_fly_format.dart';
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

class _CompactAlertsBanner extends StatefulWidget {
  final DashboardAlerts alerts;

  const _CompactAlertsBanner({required this.alerts});

  @override
  State<_CompactAlertsBanner> createState() => _CompactAlertsBannerState();
}

class _CompactAlertsBannerState extends State<_CompactAlertsBanner> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant _CompactAlertsBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// The no-fly label is derived from `DateTime.now()`, so refresh it once a
  /// minute while a restriction is active (matching SafetyHubPage). No ticker
  /// runs when there is no countdown to update.
  void _syncTicker() {
    final active = widget.alerts.noFlyStatus != null;
    if (active && _ticker == null) {
      _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!active && _ticker != null) {
      _ticker!.cancel();
      _ticker = null;
    }
  }

  String _alertText(BuildContext context) {
    final alerts = widget.alerts;
    final noFly = alerts.noFlyStatus;
    if (noFly != null) {
      return context.l10n.safetyHub_alert_noFly(
        formatNoFlyRemaining(noFly.remaining(DateTime.now().toUtc())),
      );
    }
    if (alerts.insuranceExpired) {
      return context.l10n.dashboard_alerts_insuranceExpired;
    }
    if (alerts.insuranceExpiringSoon) {
      return context.l10n.dashboard_alerts_insuranceExpiringSoon;
    }
    final equipment = alerts.equipmentServiceDue.first;
    final daysUntil = equipment.daysUntilService;
    final isOverdue = daysUntil != null && daysUntil < 0;
    return isOverdue
        ? context.l10n.dashboard_alerts_equipmentServiceOverdue(equipment.name)
        : context.l10n.dashboard_alerts_equipmentServiceDue(equipment.name);
  }

  void _onTap(BuildContext context) {
    final alerts = widget.alerts;
    if (alerts.noFlyStatus != null) {
      context.push('/safety');
      return;
    }
    if (alerts.alertCount == 1) {
      if (alerts.insuranceExpired || alerts.insuranceExpiringSoon) {
        context.go('/settings');
        return;
      }
      if (alerts.equipmentServiceDue.isNotEmpty) {
        final equipment = alerts.equipmentServiceDue.first;
        context.push('/equipment/${equipment.id}');
        return;
      }
    }
    context.go('/settings');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final alerts = widget.alerts;
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
