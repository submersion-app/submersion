import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart_host.dart';
import 'package:submersion/features/planner/domain/entities/plan_series.dart';
import 'package:submersion/features/planner/domain/entities/series_follow.dart';
import 'package:submersion/features/planner/domain/utils/hours_minutes.dart';
import 'package:submersion/features/planner/presentation/providers/plan_follow_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// How a logged dive goes by in the series bar: its dive number, else its
/// name, else its date.
String seriesLoggedDiveLabel(SeriesLoggedDive dive, UnitFormatter units) {
  final number = dive.diveNumber;
  if (number != null) return '#$number';
  final name = dive.name;
  if (name != null && name.isNotEmpty) return name;
  return units.formatDate(dive.start);
}

/// A logged dive picked in the series bar (issue #3565), in place of the
/// planner: its actual profile, read-only, a way back to it in the log, and
/// what it passes on to the dive after it.
///
/// [chartHeight] fixes the chart's height where the view scrolls (phone);
/// null lets the chart take the height left over.
class PlanLoggedDiveView extends ConsumerWidget {
  const PlanLoggedDiveView({super.key, this.chartHeight});

  final double? chartHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logged = ref.watch(viewedLoggedDiveProvider);
    final series = ref.watch(planSeriesNotifierProvider);
    final follow = series.follow;
    if (logged == null || follow == null) return const SizedBox.shrink();

    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));
    final label = seriesLoggedDiveLabel(logged, units);
    final dive = ref.watch(diveProvider(logged.id));
    final analysis = ref.watch(profileAnalysisProvider(logged.id)).valueOrNull;

    // The dive after this one: the next logged dive, else the first planned.
    final index = follow.loggedDives.indexOf(logged);
    final isFollowed = index == follow.loggedDives.length - 1;
    final String nextLabel;
    final Duration interval;
    if (isFollowed) {
      final first = series.dives.first;
      nextLabel = first.name ?? l10n.plannerSeries_dive(seriesDiveLetter(0));
      interval = first.state.surfaceInterval ?? defaultSeriesSurfaceInterval;
    } else {
      final next = follow.loggedDives[index + 1];
      nextLabel = seriesLoggedDiveLabel(next, units);
      final gap = next.start.difference(logged.end);
      interval = gap.isNegative ? Duration.zero : gap;
    }

    final chart = dive.when(
      data: (dive) => dive == null || dive.profile.isEmpty
          ? _Placeholder(message: l10n.dashboard_recentDives_noProfileData)
          : DiveProfileChartHost(dive: dive),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) =>
          _Placeholder(message: l10n.dashboard_recentDives_profileLoadError),
    );
    final tanks = [
      for (final tank in dive.valueOrNull?.tanks ?? const <DiveTank>[])
        if (tank.endPressure != null) tank,
    ];

    final subtitle = [
      if (logged.diveNumber != null &&
          logged.name != null &&
          logged.name!.isNotEmpty)
        logged.name!,
      units.formatDateTime(logged.start, l10n: l10n),
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Column(
        mainAxisSize: chartHeight == null ? MainAxisSize.max : MainAxisSize.min,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.plannerSeries_loggedDive(label),
                      style: theme.textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.open_in_new, size: 18),
                label: Text(l10n.plannerSeries_openInLog),
                onPressed: () => context.push('/dives/${logged.id}'),
              ),
              if (isFollowed)
                TextButton.icon(
                  icon: const Icon(Icons.link_off, size: 18),
                  label: Text(l10n.plannerSeries_stopFollowing),
                  onPressed: () =>
                      ref.read(planSeriesNotifierProvider.notifier).unfollow(),
                ),
            ],
          ),
          if (chartHeight case final height?)
            SizedBox(height: height, child: chart)
          else
            Expanded(child: chart),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.plannerSeries_carriedInto(nextLabel),
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 24,
                    runSpacing: 8,
                    children: [
                      _Fact(
                        label: l10n.plannerSeries_surfaceInterval,
                        value: formatHoursMinutes(interval),
                      ),
                      if (analysis != null) ...[
                        _Fact(
                          label: l10n.plannerSeries_endCns,
                          value:
                              '${analysis.o2Exposure.cnsEnd.toStringAsFixed(0)}%',
                        ),
                        _Fact(
                          label: l10n.plannerSeries_otu,
                          value: analysis.o2Exposure.otu.toStringAsFixed(0),
                        ),
                      ],
                      for (final tank in tanks)
                        _Fact(
                          label: tank.name?.isNotEmpty ?? false
                              ? tank.name!
                              : tank.gasMix.name,
                          value: units.formatPressure(tank.endPressure),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
