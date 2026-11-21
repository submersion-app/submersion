import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/gas_consumption_display.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dashboard/presentation/providers/home_panel_providers.dart';
import 'package:submersion/features/dashboard/presentation/widgets/home_charts.dart';
import 'package:submersion/features/dashboard/presentation/widgets/home_panel.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The diver's gas consumption over their last 30 dives that have one, in
/// the lane they read (SAC in bar a minute, or RMV in litres a minute).
class SacTrendPanel extends ConsumerWidget {
  const SacTrendPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final units = ref.watch(unitFormatterProvider);
    final sac = ref.watch(homeSacLaneProvider) == GasConsumptionLane.sac;
    final series = ref.watch(homeSacSeriesProvider);
    final points = series.value ?? const <TrendDataPoint>[];
    final shown = [
      for (final p in points)
        sac ? units.convertSac(p.value) : units.convertRmv(p.value),
    ];
    final unit = sac ? units.sacSymbol : units.rmvSymbol;
    // Spoken with its unit, at the unit's own precision.
    final latest = points.isEmpty
        ? null
        : sac
        ? units.formatSac(points.last.value)
        : units.formatRmv(points.last.value);
    return HomePanel(
      title: sac
          ? l10n.dashboard_panel_sacTrend
          : l10n.dashboard_panel_rmvTrend,
      trailing: points.isEmpty
          ? null
          : '${l10n.dashboard_panel_lastDives(points.length)} · $unit',
      semanticsValue: latest ?? '',
      onTap: () => context.push('/insights'),
      child: HomePanelAsync<List<TrendDataPoint>>(
        value: series,
        isEmpty: (p) => p.isEmpty,
        emptyText: l10n.dashboard_panel_noSac,
        builder: (_) => HomeSparkline(shown, fill: true),
      ),
    );
  }
}
