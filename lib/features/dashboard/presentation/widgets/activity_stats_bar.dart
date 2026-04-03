import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A full-width card showing three activity stats side by side:
/// days since last dive, dives this month, and dives this year.
class ActivityStatsBar extends ConsumerWidget {
  const ActivityStatsBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daysSinceAsync = ref.watch(daysSinceLastDiveProvider);
    final monthlyAsync = ref.watch(monthlyDiveCountProvider);
    final ytdAsync = ref.watch(yearToDateDiveCountProvider);
    final theme = Theme.of(context);

    final daysSince = daysSinceAsync.valueOrNull;
    String daysSinceValue;
    if (daysSince == null) {
      daysSinceValue = '-';
    } else if (daysSince == 0) {
      daysSinceValue = context.l10n.dashboard_hero_todayLabel;
    } else {
      daysSinceValue = daysSince.toString();
    }

    final monthly = monthlyAsync.valueOrNull?.toString() ?? '-';
    final ytd = ytdAsync.valueOrNull?.toString() ?? '-';
    final year = DateTime.now().year.toString();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Expanded(
                child: _StatCell(
                  value: daysSinceValue,
                  label: context.l10n.dashboard_hero_daysSinceLabel,
                  theme: theme,
                ),
              ),
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: theme.dividerColor,
              ),
              Expanded(
                child: _StatCell(
                  value: monthly,
                  label: context.l10n.dashboard_hero_thisMonthLabel,
                  theme: theme,
                ),
              ),
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: theme.dividerColor,
              ),
              Expanded(
                child: _StatCell(
                  value: ytd,
                  label: context.l10n.dashboard_activityStats_divesInYear(year),
                  theme: theme,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String value;
  final String label;
  final ThemeData theme;

  const _StatCell({
    required this.value,
    required this.label,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
