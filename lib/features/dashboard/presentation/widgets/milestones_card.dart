import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/dashboard/presentation/providers/milestone_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Upcoming milestones: next round-number dive and certification
/// anniversaries.
class MilestonesCard extends ConsumerWidget {
  const MilestonesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final milestonesAsync = ref.watch(milestonesProvider);
    final milestones = milestonesAsync.valueOrNull;
    if (milestones == null || milestones.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.dashboard_milestones_title,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (milestones.nextMilestone != null)
              _row(
                context,
                Icons.flag_outlined,
                context.l10n.dashboard_milestones_nextDive(
                  milestones.divesRemaining!,
                  milestones.nextMilestone!,
                ),
              ),
            for (final anniversary in milestones.anniversaries)
              _row(
                context,
                Icons.workspace_premium_outlined,
                context.l10n.dashboard_milestones_certYears(
                  anniversary.certName,
                  anniversary.years,
                  DateFormat.MMMM(locale).format(anniversary.date),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, IconData icon, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}
