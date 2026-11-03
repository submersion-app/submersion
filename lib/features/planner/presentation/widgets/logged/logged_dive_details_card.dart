import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_lab/presentation/pages/dive_lab_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/planner/domain/entities/series_follow.dart';
import 'package:submersion/features/planner/domain/utils/hours_minutes.dart';
import 'package:submersion/features/planner/presentation/providers/plan_follow_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_logged_dive_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/logged/logged_dive_label.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Dive details card for a logged dive picked in the series bar (issue
/// #3565): the same card and fields as a planned dive's, read-only, so
/// nothing moves when the diver changes dives. Its header opens the dive in
/// the log, compares it with its plan when it had one, and stops following
/// on the dive the series follows.
class LoggedDiveDetailsCard extends ConsumerWidget {
  const LoggedDiveDetailsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logged = ref.watch(viewedLoggedDiveProvider);
    final follow = ref.watch(
      planSeriesNotifierProvider.select((s) => s.follow),
    );
    if (logged == null || follow == null) return const SizedBox.shrink();

    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = ref.watch(unitFormatterProvider);
    final dive = ref.watch(diveProvider(logged.id)).value;
    final planned = ref.watch(viewedLoggedDivePlanProvider) != null;

    final index = follow.loggedDives.indexOf(logged);
    final isFollowed = index == follow.loggedDives.length - 1;
    // The gap since the logged dive before it; the first has none shown.
    final Duration? interval = index > 0
        ? _gap(follow.loggedDives[index - 1], logged)
        : null;

    final label = seriesLoggedDiveLabel(logged, units);
    final number = logged.diveNumber;
    final name = [
      label,
      if (number != null && label != '#$number') '#$number',
    ].join(' · ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ExcludeSemantics(
                  child: Icon(
                    Icons.scuba_diving,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.plannerSeries_diveDetails,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.open_in_new),
                  tooltip: l10n.plannerSeries_openInLog,
                  onPressed: () => context.push('/dives/${logged.id}'),
                ),
                if (planned)
                  IconButton(
                    icon: const Icon(Icons.compare_arrows),
                    tooltip: l10n.plannerSeries_compareWithPlan,
                    onPressed: () => showDiveLab(context, logged.id),
                  ),
                if (isFollowed)
                  IconButton(
                    icon: const Icon(Icons.link_off),
                    tooltip: l10n.plannerSeries_stopFollowing,
                    onPressed: () => ref
                        .read(planSeriesNotifierProvider.notifier)
                        .unfollow(),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _ReadOnlyField(
              fieldKey: const Key('loggedDiveName'),
              label: l10n.plannerSeries_diveName,
              value: name,
            ),
            const SizedBox(height: 16),
            _ReadOnlyField(
              fieldKey: const Key('loggedDiveStart'),
              label: l10n.plannerSeries_start,
              icon: Icons.schedule,
              value: units.formatDateTime(logged.start, l10n: l10n),
            ),
            const SizedBox(height: 16),
            _ReadOnlyField(
              fieldKey: const Key('loggedDiveInterval'),
              label: l10n.plannerSeries_surfaceInterval,
              icon: Icons.hourglass_bottom,
              value: interval == null ? null : formatHoursMinutes(interval),
            ),
            const SizedBox(height: 16),
            _ReadOnlyField(
              fieldKey: const Key('loggedDiveSite'),
              label: l10n.plannerSeries_site,
              icon: Icons.location_on_outlined,
              value: dive?.site?.name ?? l10n.plannerSeries_site_none,
            ),
          ],
        ),
      ),
    );
  }

  static Duration _gap(SeriesLoggedDive before, SeriesLoggedDive dive) {
    final gap = dive.start.difference(before.end);
    return gap.isNegative ? Duration.zero : gap;
  }
}

/// A field shown as a planned dive's is, but not editable. A null [value]
/// greys it out, as a planned first dive's interval is.
class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({
    required this.fieldKey,
    required this.label,
    required this.value,
    this.icon,
  });

  final Key fieldKey;
  final String label;
  final String? value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      key: fieldKey,
      decoration: InputDecoration(
        isDense: true,
        enabled: value != null,
        border: const OutlineInputBorder(),
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        prefixIcon: icon == null ? null : Icon(icon),
      ),
      child: Text(value ?? '', overflow: TextOverflow.ellipsis),
    );
  }
}
