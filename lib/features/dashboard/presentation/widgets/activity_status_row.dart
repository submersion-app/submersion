import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A row of activity status cards showing days since last dive, monthly count, and YTD
class ActivityStatusRow extends ConsumerWidget {
  const ActivityStatusRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(child: _DaysSinceLastDiveCard()),
        const SizedBox(width: 8),
        Expanded(child: _MonthlyDiveCountCard()),
        const SizedBox(width: 8),
        Expanded(child: _YearToDateCard()),
      ],
    );
  }
}

class _DaysSinceLastDiveCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daysAsync = ref.watch(daysSinceLastDiveProvider);
    final theme = Theme.of(context);

    return daysAsync.when(
      data: (days) {
        final displayText = days == null
            ? '-'
            : days == 0
            ? context.l10n.dashboard_activity_today
            : '$days';
        final subtitle = days == null
            ? context.l10n.dashboard_activity_noDivesYet
            : days == 0
            ? context.l10n.dashboard_activity_lastDive
            : days == 1
            ? context.l10n.dashboard_activity_daySinceDiving
            : context.l10n.dashboard_activity_daysSinceDiving;

        return _StatusCard(
          value: displayText,
          label: subtitle,
          icon: Icons.access_time,
          color: theme.colorScheme.primary,
        );
      },
      loading: () => _StatusCard(
        value: '...',
        label: context.l10n.dashboard_activity_loading,
        icon: Icons.access_time,
        color: theme.colorScheme.primary,
        isLoading: true,
      ),
      error: (_, _) => _StatusCard(
        value: '-',
        label: context.l10n.dashboard_activity_error,
        icon: Icons.access_time,
        color: theme.colorScheme.error,
      ),
    );
  }
}

class _MonthlyDiveCountCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(monthlyDiveCountProvider);
    final theme = Theme.of(context);

    return countAsync.when(
      data: (count) => _StatusCard(
        value: '$count',
        label: count == 1
            ? context.l10n.dashboard_activity_diveThisMonth
            : context.l10n.dashboard_activity_divesThisMonth,
        icon: Icons.calendar_today,
        color: theme.colorScheme.secondary,
      ),
      loading: () => _StatusCard(
        value: '...',
        label: context.l10n.dashboard_activity_divesThisMonth,
        icon: Icons.calendar_today,
        color: theme.colorScheme.secondary,
        isLoading: true,
      ),
      error: (_, _) => _StatusCard(
        value: '-',
        label: context.l10n.dashboard_activity_divesThisMonth,
        icon: Icons.calendar_today,
        color: theme.colorScheme.error,
      ),
    );
  }
}

class _YearToDateCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(yearToDateDiveCountProvider);
    final theme = Theme.of(context);
    final year = DateTime.now().year;

    return countAsync.when(
      data: (count) => _StatusCard(
        value: '$count',
        label: count == 1
            ? context.l10n.dashboard_activity_diveInYear(year)
            : context.l10n.dashboard_activity_divesInYear(year),
        icon: Icons.trending_up,
        color: theme.colorScheme.tertiary,
      ),
      loading: () => _StatusCard(
        value: '...',
        label: context.l10n.dashboard_activity_divesInYear(year),
        icon: Icons.trending_up,
        color: theme.colorScheme.tertiary,
        isLoading: true,
      ),
      error: (_, _) => _StatusCard(
        value: '-',
        label: context.l10n.dashboard_activity_divesInYear(year),
        icon: Icons.trending_up,
        color: theme.colorScheme.error,
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final bool isLoading;

  const _StatusCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: '$value $label',
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 4),
            if (isLoading)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              )
            else
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            const SizedBox(height: 1),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
