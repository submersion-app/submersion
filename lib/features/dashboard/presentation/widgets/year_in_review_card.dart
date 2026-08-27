import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';

import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// This year vs last year mini-stats.
class YearInReviewCard extends ConsumerWidget {
  const YearInReviewCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewAsync = ref.watch(yearInReviewProvider);
    final review = reviewAsync.valueOrNull;
    if (review == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final fmt = UnitFormatter(settings);
    final seconds = review.current.totalSeconds;
    // Round to one decimal first, then pick the format from the rounded
    // value: otherwise 9.96h would fail the `< 10` test yet render as
    // "10.0" once the decimal is applied.
    final hoursRounded = double.parse((seconds / 3600).toStringAsFixed(1));
    final hoursText = hoursRounded >= 10
        ? hoursRounded.round().toString()
        : hoursRounded.toStringAsFixed(1);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.dashboard_yearInReview_title,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _row(
              context,
              Icons.scuba_diving,
              context.l10n.dashboard_yearInReview_divesVs(
                review.current.diveCount,
                review.previous.diveCount,
              ),
            ),
            if (seconds > 0)
              _row(
                context,
                Icons.timer_outlined,
                context.l10n.dashboard_yearInReview_hours(hoursText),
              ),
            if (review.current.maxDepth != null)
              _row(
                context,
                Icons.arrow_downward,
                context.l10n.dashboard_yearInReview_maxDepth(
                  fmt.formatDepth(review.current.maxDepth),
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
