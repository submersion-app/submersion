import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dashboard/presentation/widgets/home_charts.dart';
import 'package:submersion/features/dashboard/presentation/widgets/home_panel.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/insights/presentation/widgets/depth_pie_card.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Dives per depth band across the whole log, with empty deep bands
/// trimmed. Band edges convert to the diver's unit, as Insights shows them.
class DepthMixPanel extends ConsumerWidget {
  const DepthMixPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final units = ref.watch(unitFormatterProvider);
    final stats = ref.watch(diveStatisticsProvider);
    // The bars are the panel's only numbers, so a screen reader hears each
    // band with its count.
    final bands = trimmedDepthBands(
      stats.value?.depthDistribution ?? const <DepthRangeStat>[],
    );
    return HomePanel(
      title: l10n.dashboard_panel_depthMix,
      semanticsValue: [
        for (final b in bands)
          '${depthBucketLabel(b, units, l10n)}: ${b.count}',
      ].join(', '),
      onTap: () => context.push('/insights'),
      child: HomePanelAsync<DiveStatistics>(
        value: stats,
        isEmpty: (s) => s.depthDistribution.every((b) => b.count == 0),
        emptyText: l10n.dashboard_panel_noDives,
        builder: (s) {
          final bands = trimmedDepthBands(s.depthDistribution);
          return HomeBars(
            [for (final b in bands) b.count.toDouble()],
            labels: [for (final b in bands) depthBucketLabel(b, units, l10n)],
          );
        },
      ),
    );
  }
}

/// The bands up to the deepest one with dives: the empty bands past it say
/// nothing and would squeeze the rest.
List<DepthRangeStat> trimmedDepthBands(List<DepthRangeStat> bands) {
  var last = bands.length - 1;
  while (last >= 0 && bands[last].count == 0) {
    last--;
  }
  return bands.sublist(0, last + 1);
}
