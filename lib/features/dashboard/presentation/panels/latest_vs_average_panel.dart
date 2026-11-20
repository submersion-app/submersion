import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/gas_consumption_display.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/features/dashboard/presentation/providers/home_panel_providers.dart';
import 'package:submersion/features/dashboard/presentation/widgets/home_charts.dart';
import 'package:submersion/features/dashboard/presentation/widgets/home_panel.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The newest dive's maximum depth, runtime and gas consumption, each as a
/// bar against the diver's average over the last twelve months. The bar
/// puts the average at the middle, so a longer bar means above average.
class LatestVsAveragePanel extends ConsumerWidget {
  const LatestVsAveragePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final units = ref.watch(unitFormatterProvider);
    final divesAsync = ref.watch(recentDivesProvider);
    final dive = divesAsync.value?.firstOrNull;
    final avg = ref.watch(homeAveragesProvider).value;
    final series = ref.watch(homeSacSeriesProvider).value ?? const [];
    final sacLane = ref.watch(homeSacLaneProvider) == GasConsumptionLane.sac;
    if (dive == null) {
      // Loading and error get their own states; only a loaded empty log
      // says there are no dives.
      return HomePanel(
        title: l10n.dashboard_panel_latestVsAverage,
        semanticsValue: '',
        child: HomePanelAsync(
          value: divesAsync,
          isEmpty: (_) => true,
          emptyText: l10n.dashboard_recentDives_empty,
          builder: (_) => const SizedBox.shrink(),
        ),
      );
    }

    // No average, no bar: a full bar would read as "far above average".
    double? fraction(double value, double? average) =>
        average == null || average <= 0
        ? null
        : math.min(1, value / (2 * average));
    String compare(String value, String? average) => average == null
        ? value
        : l10n.dashboard_panel_vsAverage(value, average);

    final rows = <Widget>[];
    final depth = dive.maxDepth;
    if (depth != null) {
      rows.add(
        HomeBarRow(
          label: l10n.dashboard_panel_maxDepth,
          value: compare(
            units.formatDepth(depth),
            avg?.averages.maxDepth == null
                ? null
                : units.formatDepth(avg!.averages.maxDepth),
          ),
          fraction: fraction(depth, avg?.averages.maxDepth),
        ),
      );
    }
    final runtime = dive.measuredRuntime;
    if (runtime != null) {
      final avgSeconds = avg?.averages.runtimeSeconds;
      rows.add(
        HomeBarRow(
          label: l10n.dashboard_panel_runtime,
          value: compare(
            "${runtime.inMinutes}'",
            avgSeconds == null ? null : "${avgSeconds ~/ 60}'",
          ),
          fraction: fraction(
            runtime.inSeconds.toDouble(),
            avgSeconds?.toDouble(),
          ),
        ),
      );
    }
    final point = series.where((p) => p.diveId == dive.id).firstOrNull;
    if (point != null) {
      String fmt(double v) =>
          (sacLane ? units.convertSac(v) : units.convertRmv(v)).toStringAsFixed(
            1,
          );
      rows.add(
        HomeBarRow(
          label: sacLane ? l10n.dashboard_panel_sac : l10n.dashboard_panel_rmv,
          value: compare(
            fmt(point.value),
            avg?.sac == null ? null : fmt(avg!.sac!),
          ),
          fraction: fraction(point.value, avg?.sac),
        ),
      );
    }

    return HomePanel(
      title: l10n.dashboard_panel_latestVsAverage,
      trailing: dive.site?.name,
      semanticsValue: dive.site?.name ?? '',
      onTap: () => context.push('/dives/${dive.id}'),
      fit: HomePanelFit.clip,
      child: Column(mainAxisSize: MainAxisSize.min, children: rows),
    );
  }
}
