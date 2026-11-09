import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/planner/domain/entities/plan_series.dart';
import 'package:submersion/features/planner/domain/entities/series_follow.dart';
import 'package:submersion/features/planner/domain/utils/hours_minutes.dart';
import 'package:submersion/features/planner/presentation/info/plan_results_info.dart';
import 'package:submersion/features/planner/presentation/providers/plan_follow_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/logged/logged_dive_label.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/info_sheet/info_button.dart';
import 'package:submersion/shared/widgets/info_sheet/info_units.dart';

/// What the logged dive in view passes on to the dive after it (issue
/// #3565): the next logged dive, else the first planned one; for a dive of
/// the series that has been dived, the dive after it. The surface
/// interval before it, the CNS and OTU it leaves, and each tank's end
/// pressure.
class LoggedDiveCarryCard extends ConsumerWidget {
  const LoggedDiveCarryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logged = ref.watch(viewedLoggedDiveProvider);
    final series = ref.watch(planSeriesNotifierProvider);
    final follow = series.follow;
    if (logged == null) return const SizedBox.shrink();
    // A followed dive, else the selected dive of the series, dived.
    final index = follow?.loggedDives.indexOf(logged) ?? -1;
    final nextPlanned = index < 0
        ? series.selectedIndex + 1
        : index == follow!.loggedDives.length - 1
        ? 0
        : null;
    // The last dive of the series passes nothing on.
    if (nextPlanned != null && nextPlanned >= series.dives.length) {
      return const SizedBox.shrink();
    }

    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = ref.watch(unitFormatterProvider);
    final dive = ref.watch(diveProvider(logged.id)).value;
    // `.value` keeps the last analysis while a settings or dive log change
    // reloads it; the `valueOrNull` polyfill would drop the facts until the
    // reload lands.
    final analysis = ref.watch(profileAnalysisProvider(logged.id)).value;

    final String nextLabel;
    final Duration interval;
    if (nextPlanned != null) {
      final next = series.dives[nextPlanned];
      nextLabel =
          next.name ?? l10n.plannerSeries_dive(seriesDiveLetter(nextPlanned));
      // As the series settles it: a fixed start's interval follows the end
      // of the dive before it, which the dive's own copy only learns when
      // it is next selected.
      final settled = ref.watch(planSeriesResultsProvider)[nextPlanned].state;
      interval = settled.surfaceInterval ?? defaultSeriesSurfaceInterval;
    } else {
      final next = follow!.loggedDives[index + 1];
      nextLabel = seriesLoggedDiveLabel(next, units);
      interval = loggedSurfaceInterval(logged, next);
    }
    final tanks = [
      for (final tank in dive?.tanks ?? const <DiveTank>[])
        if (tank.endPressure != null) tank,
    ];

    return Card(
      key: const Key('loggedDiveCarryCard'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      l10n.plannerSeries_carriedInto(nextLabel),
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  HeaderInfoButton(
                    title: l10n.plannerSeries_carriedInto(nextLabel),
                    height: 20,
                    content: (context) => planCarryInfo(
                      context.l10n,
                      infoUnits(context),
                      title: context.l10n.plannerSeries_carriedInto(nextLabel),
                      showsOtu: analysis != null,
                    ),
                  ),
                ],
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
