import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../equipment/domain/entities/equipment_item.dart';
import '../providers/dashboard_providers.dart';

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
      error: (_, __) => const SizedBox.shrink(),
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
                Icon(
                  Icons.notification_important,
                  color: theme.colorScheme.error,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Alerts & Reminders',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
              ],
            ),
            const SizedBox(height: 12),
            // Insurance alerts
            if (alerts.insuranceExpired)
              _AlertTile(
                icon: Icons.warning_amber,
                iconColor: theme.colorScheme.error,
                title: 'Insurance Expired',
                subtitle: alerts.insuranceProvider != null
                    ? '${alerts.insuranceProvider} expired'
                    : 'Your dive insurance has expired',
                actionLabel: 'Update',
                onAction: () => context.go('/settings'),
              ),
            if (alerts.insuranceExpiringSoon && !alerts.insuranceExpired)
              _AlertTile(
                icon: Icons.schedule,
                iconColor: Colors.orange,
                title: 'Insurance Expiring Soon',
                subtitle: alerts.insuranceExpiryDate != null
                    ? 'Expires ${DateFormat.MMMd().format(alerts.insuranceExpiryDate!)}'
                    : 'Check your insurance expiry date',
                actionLabel: 'View',
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
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
          TextButton(
            onPressed: onAction,
            child: Text(actionLabel),
          ),
        ],
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
      title: '${equipment.name} Service ${isOverdue ? 'Overdue' : 'Due'}',
      subtitle: _getServiceSubtitle(daysOverdue),
      actionLabel: 'View',
      onAction: () => context.go('/equipment/${equipment.id}'),
    );
  }

  String _getServiceSubtitle(int? daysUntilService) {
    if (daysUntilService == null) {
      return 'Service interval reached';
    }
    if (daysUntilService < 0) {
      final overdue = -daysUntilService;
      return '$overdue day${overdue == 1 ? '' : 's'} overdue';
    }
    if (daysUntilService == 0) {
      return 'Service due today';
    }
    return 'Due in $daysUntilService day${daysUntilService == 1 ? '' : 's'}';
  }
}
