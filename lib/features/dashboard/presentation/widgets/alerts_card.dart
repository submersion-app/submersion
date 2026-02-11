import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/accessibility/semantic_helpers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A card showing alerts and reminders (equipment service, insurance expiry)
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
        return _AlertsCardContent(alerts: alerts);
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _AlertsCardContent extends StatelessWidget {
  final DashboardAlerts alerts;

  const _AlertsCardContent({required this.alerts});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ExcludeSemantics(
                  child: Icon(
                    Icons.notification_important,
                    color: theme.colorScheme.error,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                Semantics(
                  header: true,
                  child: Text(
                    context.l10n.dashboard_alerts_sectionTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                Semantics(
                  label: context.l10n.dashboard_semantics_activeAlerts(
                    alerts.alertCount,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${alerts.alertCount}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onError,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Insurance alerts
            if (alerts.insuranceExpired)
              _AlertTile(
                icon: Icons.warning_amber,
                iconColor: theme.colorScheme.error,
                title: context.l10n.dashboard_alerts_insuranceExpired,
                subtitle: alerts.insuranceProvider != null
                    ? context.l10n.dashboard_alerts_insuranceExpiredProvider(
                        alerts.insuranceProvider!,
                      )
                    : context.l10n.dashboard_alerts_insuranceExpiredGeneric,
                actionLabel: context.l10n.dashboard_alerts_actionUpdate,
                onAction: () => context.go('/settings'),
              ),
            if (alerts.insuranceExpiringSoon && !alerts.insuranceExpired)
              _AlertTile(
                icon: Icons.schedule,
                iconColor: Colors.orange,
                title: context.l10n.dashboard_alerts_insuranceExpiringSoon,
                subtitle: alerts.insuranceExpiryDate != null
                    ? context.l10n.dashboard_alerts_insuranceExpiresDate(
                        DateFormat.MMMd().format(alerts.insuranceExpiryDate!),
                      )
                    : context.l10n.dashboard_alerts_checkInsuranceExpiry,
                actionLabel: context.l10n.dashboard_alerts_actionView,
                onAction: () => context.go('/settings'),
              ),
            // Equipment service alerts
            ...alerts.equipmentServiceDue.map(
              (equipment) => _EquipmentAlertTile(equipment: equipment),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  const _AlertTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: listItemLabel(title: title, subtitle: subtitle),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

class _EquipmentAlertTile extends StatelessWidget {
  final EquipmentItem equipment;

  const _EquipmentAlertTile({required this.equipment});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final daysOverdue = equipment.daysUntilService;
    final isOverdue = daysOverdue != null && daysOverdue < 0;

    return _AlertTile(
      icon: Icons.build,
      iconColor: isOverdue ? theme.colorScheme.error : Colors.orange,
      title: isOverdue
          ? context.l10n.dashboard_alerts_equipmentServiceOverdue(
              equipment.name,
            )
          : context.l10n.dashboard_alerts_equipmentServiceDue(equipment.name),
      subtitle: _getServiceSubtitle(context, daysOverdue),
      actionLabel: context.l10n.dashboard_alerts_actionView,
      onAction: () => context.go('/equipment/${equipment.id}'),
    );
  }

  String _getServiceSubtitle(BuildContext context, int? daysUntilService) {
    if (daysUntilService == null) {
      return context.l10n.dashboard_alerts_serviceIntervalReached;
    }
    if (daysUntilService < 0) {
      final overdue = -daysUntilService;
      return overdue == 1
          ? context.l10n.dashboard_alerts_daysOverdueOne
          : context.l10n.dashboard_alerts_daysOverdueOther(overdue);
    }
    if (daysUntilService == 0) {
      return context.l10n.dashboard_alerts_serviceDueToday;
    }
    return daysUntilService == 1
        ? context.l10n.dashboard_alerts_dueInDaysOne
        : context.l10n.dashboard_alerts_dueInDaysOther(daysUntilService);
  }
}
