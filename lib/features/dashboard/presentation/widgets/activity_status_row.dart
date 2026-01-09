import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import '../providers/dashboard_providers.dart';

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
        final color = _getDaysColor(days);
        final displayText = days == null
            ? '-'
            : days == 0
            ? 'Today!'
            : '$days';
        final subtitle = days == null
            ? 'No dives yet'
            : days == 0
            ? 'Last dive'
            : days == 1
            ? 'Day since diving'
            : 'Days since diving';

        return _StatusCard(
          value: displayText,
          label: subtitle,
          icon: Icons.access_time,
          color: color,
        );
      },
      loading: () => _StatusCard(
        value: '...',
        label: 'Loading',
        icon: Icons.access_time,
        color: theme.colorScheme.primary,
        isLoading: true,
      ),
      error: (_, _) => _StatusCard(
        value: '-',
        label: 'Error',
        icon: Icons.access_time,
        color: theme.colorScheme.error,
      ),
    );
  }

  Color _getDaysColor(int? days) {
    if (days == null) return Colors.grey;
    if (days <= 7) return Colors.green;
    if (days <= 30) return Colors.orange;
    return Colors.red.shade400;
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
        label: count == 1 ? 'Dive this month' : 'Dives this month',
        icon: Icons.calendar_today,
        color: theme.colorScheme.secondary,
      ),
      loading: () => _StatusCard(
        value: '...',
        label: 'Dives this month',
        icon: Icons.calendar_today,
        color: theme.colorScheme.secondary,
        isLoading: true,
      ),
      error: (_, _) => _StatusCard(
        value: '-',
        label: 'Dives this month',
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
        label: count == 1 ? 'Dive in $year' : 'Dives in $year',
        icon: Icons.trending_up,
        color: theme.colorScheme.tertiary,
      ),
      loading: () => _StatusCard(
        value: '...',
        label: 'Dives in $year',
        icon: Icons.trending_up,
        color: theme.colorScheme.tertiary,
        isLoading: true,
      ),
      error: (_, _) => _StatusCard(
        value: '-',
        label: 'Dives in $year',
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

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          if (isLoading)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          else
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
