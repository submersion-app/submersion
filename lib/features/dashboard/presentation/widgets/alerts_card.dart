import 'dart:async';

import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/safety/presentation/formatters/no_fly_format.dart';
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
    // Drive off hasActiveNoFly (not just non-null): a cached-but-elapsed status
    // needs no countdown refresh.
    final active = widget.alerts.hasActiveNoFly;
    if (active && _ticker == null) {
      _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
        if (!mounted) return;
        // Stop waking up once the restriction elapses; the provider re-emit
        // removes the banner shortly after, but don't tick until then.
        if (!widget.alerts.hasActiveNoFly) {
          _ticker?.cancel();
          _ticker = null;
        }
        setState(() {});
      });
    } else if (!active && _ticker != null) {
      _ticker!.cancel();
      _ticker = null;
    }
  }

  String _alertText(BuildContext context) {
    final alerts = widget.alerts;
    final noFly = alerts.noFlyStatus;
    // A cached status can expire while the dashboard stays mounted; only show
    // the countdown while it is still active, otherwise fall through to the
    // next-priority alert. Sample the clock once so the active check and the
    // remaining-time label agree at the expiry boundary.
    final now = DateTime.now().toUtc();
    if (noFly != null && noFly.isActiveAt(now)) {
      return context.l10n.safetyHub_alert_noFly(
        formatNoFlyRemaining(noFly.remaining(now)),
      );
    }
    if (alerts.insuranceExpired) {
      return context.l10n.dashboard_alerts_insuranceExpired;
    }
    if (alerts.insuranceExpiringSoon) {
      return context.l10n.dashboard_alerts_insuranceExpiringSoon;
    }
    if (alerts.serviceClocksDue.isEmpty) {
      // The minute ticker can rebuild this banner in the brief window between a
      // sole no-fly restriction elapsing and the provider re-emitting to remove
      // the banner. Render nothing rather than reading .first on an empty list.
      return '';
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
    final alerts = widget.alerts;
    if (alerts.hasActiveNoFly) {
      context.push('/safety');
      return;
    }
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
    final alerts = widget.alerts;
    final alertText = _alertText(context);

    // No renderable alert (e.g. the sole no-fly restriction just elapsed and
    // the ticker rebuilt before the provider re-emitted): hide the row rather
    // than show an empty label with a chevron and count.
    if (alertText.isEmpty) return const SizedBox.shrink();

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
