import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/explore/domain/chart_selection.dart';
import 'package:submersion/features/explore/domain/query_model.dart';
import 'package:submersion/features/explore/presentation/providers/explore_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/insights/presentation/widgets/dive_trend_chart.dart';
import 'package:submersion/features/insights/presentation/widgets/horizontal_category_bar_chart.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The chart cards the compiler asked for, at most three.
class ExploreCharts extends StatelessWidget {
  const ExploreCharts({super.key, required this.requests});
  final List<ChartRequest> requests;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [for (final r in requests) _ExploreChartCard(request: r)],
    );
  }
}

class _ExploreChartCard extends ConsumerWidget {
  const _ExploreChartCard({required this.request});
  final ChartRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final dateFormat = ref.watch(dateFormatProvider);
    final data = ref.watch(exploreChartDataProvider(request));
    final title = switch (request.kind) {
      ChartKind.divesOverTime => l10n.explore_chart_divesOverTime,
      ChartKind.depthTrend => l10n.explore_chart_depthTrend,
      ChartKind.waterTempTrend => l10n.explore_chart_waterTempTrend,
      ChartKind.bottomTimeTrend => l10n.explore_chart_bottomTimeTrend,
      ChartKind.entityCounts => l10n.explore_chart_entityCounts(
        _kindName(l10n, request.entityKind),
      ),
    };
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            data.when(
              loading: () => const SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) =>
                  SizedBox(height: 80, child: Center(child: Text('$e'))),
              data: (d) => request.kind == ChartKind.entityCounts
                  ? HorizontalCategoryBarChart(data: d.bars)
                  : DiveTrendChart(
                      points: d.points,
                      height: 180,
                      chartId: 'explore-${request.kind.name}',
                      dateFormat: dateFormat,
                      valueFormatter: (v) => switch (request.kind) {
                        ChartKind.depthTrend => units.formatDepth(v),
                        ChartKind.waterTempTrend => units.formatTemperature(v),
                        ChartKind.bottomTimeTrend => '${v.round()} min',
                        _ => '${v.round()}',
                      },
                      yAxisFormatter: (v) => switch (request.kind) {
                        ChartKind.depthTrend => units.formatDepth(
                          v,
                          decimals: 0,
                        ),
                        ChartKind.waterTempTrend => units.formatTemperature(
                          v,
                          decimals: 0,
                        ),
                        _ => '${v.round()}',
                      },
                      onDiveSelected: (id) => context.push('/dives/$id'),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static String _kindName(AppLocalizations l10n, MentionKind? k) => switch (k) {
    MentionKind.site || MentionKind.place => l10n.explore_kind_site,
    MentionKind.species => l10n.explore_kind_species,
    MentionKind.gear => l10n.explore_kind_gear,
    MentionKind.buddy => l10n.explore_kind_buddy,
    MentionKind.tag => l10n.explore_kind_tag,
    MentionKind.center => l10n.explore_kind_center,
    MentionKind.trip => l10n.explore_kind_trip,
    MentionKind.computer => l10n.explore_kind_computer,
    null => '',
  };
}
