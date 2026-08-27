import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_decimator.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Points kept for rendering. A preview is a few hundred pixels wide, so more
/// samples than this cannot resolve to distinct pixels; the decimator keeps
/// the depth envelope, so the max-depth spike survives the reduction.
const int _renderPoints = 240;

/// Depth profile of the newest dive, shown beside the recent-dives list on
/// wide windows.
///
/// The list itself is pinned to the width a dive card has on the Dives page,
/// so on a wide desktop window there is a large amount of space left over.
/// This fills it with the one thing a dive list row cannot show: the shape of
/// the dive.
///
/// Deliberately not [DiveProfileChart]: that widget is ~5,800 lines carrying
/// touch recognisers, tooltips, playback, tissue curves and safety findings,
/// and mounting it on the home screen would cost the first frame far more
/// than a static preview is worth. This is read-only and non-interactive;
/// tapping anywhere opens the dive itself.
class RecentDiveProfilePreview extends ConsumerWidget {
  const RecentDiveProfilePreview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final divesAsync = ref.watch(recentDivesProvider);
    final dive = divesAsync.valueOrNull?.firstOrNull;
    if (dive == null) return const SizedBox.shrink();

    final profileAsync = ref.watch(latestDiveProfileProvider);

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/dives/${dive.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(dive: dive),
              const SizedBox(height: 8),
              Expanded(
                child: profileAsync.when(
                  data: (profile) => profile == null
                      ? _Placeholder(
                          icon: Icons.show_chart,
                          message:
                              context.l10n.dashboard_recentDives_noProfileData,
                        )
                      : _ProfileChart(profile: profile),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  // A failed load and a dive with no samples are different
                  // facts. Reporting "no profile data" for a failure hides the
                  // error and tells the diver something untrue about the dive.
                  error: (_, _) => _Placeholder(
                    icon: Icons.error_outline,
                    message:
                        context.l10n.dashboard_recentDives_profileLoadError,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.dive});

  final Dive dive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final formatter = UnitFormatter(ref.watch(settingsProvider));
    final siteName = dive.site?.name;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.dashboard_recentDives_latestProfileTitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (siteName != null && siteName.isNotEmpty)
                Text(
                  siteName,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        if (dive.maxDepth != null)
          Text(
            formatter.formatDepth(dive.maxDepth),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
      ],
    );
  }
}

class _ProfileChart extends ConsumerWidget {
  const _ProfileChart({required this.profile});

  final List<DiveProfilePoint> profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final formatter = UnitFormatter(ref.watch(settingsProvider));
    final lineColor = theme.colorScheme.primary;

    // Depths are stored in metres; convert before plotting so the axis labels
    // and the curve agree with the diver's unit setting.
    final kept = decimateSeriesIndices([
      for (final p in profile) p.depth,
    ], targetPoints: _renderPoints);
    final spots = [
      for (final i in kept)
        FlSpot(
          profile[i].timestamp / 60.0,
          -formatter.convertDepth(profile[i].depth),
        ),
    ];
    if (spots.length < 2) {
      return _Placeholder(
        icon: Icons.show_chart,
        message: context.l10n.dashboard_recentDives_noProfileData,
      );
    }

    final deepest = spots.map((s) => -s.y).reduce(math.max);
    final lastMinute = spots.last.x;
    // A little headroom under the deepest point so the trace never touches
    // the axis, and a floor so a shallow dive still gets a sane scale.
    final depthAxisMax = math.max(deepest * 1.15, 1.0);

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: lastMinute <= 0 ? 1 : lastMinute,
        minY: -depthAxisMax,
        maxY: 0,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              getTitlesWidget: (value, meta) {
                if (value == meta.max || value == meta.min) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    '${(-value).round()}${formatter.depthSymbol}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (value, meta) {
                if (value == meta.max || value == meta.min) {
                  return const SizedBox.shrink();
                }
                return Text(
                  context.l10n.dashboard_recentDives_profileMinutes(
                    value.round(),
                  ),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        // Static preview: the interactive chart lives on the dive detail page,
        // and a touch handler here would fight the InkWell that opens it.
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.2,
            color: lineColor,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: lineColor.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 32,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
