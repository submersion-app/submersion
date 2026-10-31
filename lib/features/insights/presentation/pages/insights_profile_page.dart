import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/accessibility/semantic_helpers.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/insights/presentation/open_chart_dives.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';
import 'package:submersion/features/insights/presentation/widgets/stat_charts.dart';
import 'package:submersion/features/insights/presentation/widgets/stat_section_card.dart';
import 'package:submersion/l10n/l10n_extension.dart';

class InsightsProfilePage extends ConsumerWidget {
  final bool embedded;

  const InsightsProfilePage({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);

    final content = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAscentDescentSection(context, ref, units),
          const SizedBox(height: 16),
          _buildTimeAtDepthSection(context, ref, units),
          const SizedBox(height: 16),
          _buildDecoSection(context, ref),
        ],
      ),
    );

    if (embedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.insights_profile_appBar_title)),
      body: content,
    );
  }

  Widget _buildAscentDescentSection(
    BuildContext context,
    WidgetRef ref,
    UnitFormatter units,
  ) {
    final ratesAsync = ref.watch(ascentDescentRatesProvider);

    return StatSectionCard(
      title: context.l10n.insights_profile_ascentDescent_title,
      subtitle: context.l10n.insights_profile_ascentDescent_subtitle,
      child: ratesAsync.when(
        data: (data) {
          if (data.avgAscent == null && data.avgDescent == null) {
            return StatEmptyState(
              icon: Icons.trending_up,
              message: context.l10n.insights_profile_ascentDescent_empty,
            );
          }

          return Row(
            children: [
              if (data.avgAscent != null)
                Expanded(
                  child: _buildRateStat(
                    context,
                    context.l10n.insights_profile_avgAscent,
                    '${units.convertDepth(data.avgAscent!).toStringAsFixed(1)} ${units.depthRateSymbol}',
                    Icons.arrow_upward,
                    Colors.green,
                  ),
                ),
              if (data.avgAscent != null && data.avgDescent != null)
                const SizedBox(width: 16),
              if (data.avgDescent != null)
                Expanded(
                  child: _buildRateStat(
                    context,
                    context.l10n.insights_profile_avgDescent,
                    '${units.convertDepth(data.avgDescent!).toStringAsFixed(1)} ${units.depthRateSymbol}',
                    Icons.arrow_downward,
                    Colors.blue,
                  ),
                ),
            ],
          );
        },
        loading: () => const SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => StatEmptyState(
          icon: Icons.error_outline,
          message: context.l10n.insights_profile_ascentDescent_error,
        ),
      ),
    );
  }

  Widget _buildRateStat(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Semantics(
      label: statLabel(name: label, value: value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            ExcludeSemantics(child: Icon(icon, color: color, size: 32)),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeAtDepthSection(
    BuildContext context,
    WidgetRef ref,
    UnitFormatter units,
  ) {
    final depthRangesAsync = ref.watch(timeAtDepthRangesProvider);

    return StatSectionCard(
      title: context.l10n.insights_profile_timeAtDepth_title,
      subtitle: context.l10n.insights_profile_timeAtDepth_subtitle,
      child: depthRangesAsync.when(
        data: (data) {
          if (data.isEmpty) {
            return StatEmptyState(
              icon: Icons.layers,
              message: context.l10n.insights_profile_timeAtDepth_empty,
            );
          }
          // The repository emits numeric bucket edges in meters; convert to
          // the user's unit and put just the numbers on each tick. The shared
          // unit ("m" or "ft") shows once on the x-axis label.
          return CategoryBarChart(
            data: data.map((d) {
              final lo = units.convertDepth(d.lowerDepth.toDouble()).round();
              final label = d.upperDepth == null
                  ? '$lo+'
                  : '$lo-${units.convertDepth(d.upperDepth!.toDouble()).round()}';
              return (label: label, count: d.minutes);
            }).toList(),
            barColor: Colors.indigo,
            valueFormatter: (value) =>
                context.l10n.insights_profile_timeAtDepth_valueFormat(value),
            xAxisLabel: units.depthSymbol,
            yAxisLabel: context.l10n.units_profileMetric_min,
          );
        },
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => StatEmptyState(
          icon: Icons.error_outline,
          message: context.l10n.insights_profile_timeAtDepth_error,
        ),
      ),
    );
  }

  Widget _buildDecoSection(BuildContext context, WidgetRef ref) {
    final decoAsync = ref.watch(decoObligationStatsProvider);

    Future<void> openDeco(
      String row,
      List<String> Function(
        ({List<String> deco, List<String> noDeco, List<String> unknown}) ids,
      )
      pick,
    ) => openChartDives(
      context,
      ref,
      chart: context.l10n.insights_profile_deco_title,
      row: row,
      load: (_, _, _) async => pick(await ref.read(decoDiveIdsProvider.future)),
    );

    return StatSectionCard(
      title: context.l10n.insights_profile_deco_title,
      subtitle: context.l10n.insights_profile_deco_subtitle,
      child: decoAsync.when(
        data: (data) {
          // The rate is over classified dives only. Dives whose source
          // recorded no deco data and whose profile cannot be analyzed are
          // reported separately rather than folded into the no-deco count,
          // which is what made this card claim 0% for a library of deco
          // dives (#623).
          final classified = data.decoCount + data.noDecoCount;
          if (classified == 0 && data.unknownCount == 0) {
            return StatEmptyState(
              icon: Icons.stop_circle,
              message: context.l10n.insights_profile_deco_empty,
            );
          }

          final percentage = classified == 0
              ? 0.0
              : data.decoCount / classified * 100;

          return Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildDecoStat(
                    context,
                    context.l10n.insights_profile_deco_decoDives,
                    data.decoCount.toString(),
                    Colors.orange,
                    onTap: data.decoCount == 0
                        ? null
                        : () => openDeco(
                            context.l10n.insights_profile_deco_decoDives,
                            (ids) => ids.deco,
                          ),
                  ),
                  _buildDecoStat(
                    context,
                    context.l10n.insights_profile_deco_noDeco,
                    data.noDecoCount.toString(),
                    Colors.green,
                    onTap: data.noDecoCount == 0
                        ? null
                        : () => openDeco(
                            context.l10n.insights_profile_deco_noDeco,
                            (ids) => ids.noDeco,
                          ),
                  ),
                  _buildDecoStat(
                    context,
                    context.l10n.insights_profile_deco_decoRate,
                    '${percentage.toStringAsFixed(1)}%',
                    Colors.blue,
                  ),
                ],
              ),
              if (data.unknownCount > 0) ...[
                const SizedBox(height: 8),
                Semantics(
                  button: true,
                  child: InkWell(
                    onTap: () => openDeco(
                      context.l10n.insights_chart_notRecorded,
                      (ids) => ids.unknown,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            context.l10n.insights_profile_deco_notRecordedHint(
                              data.unknownCount,
                            ),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Semantics(
                label: context.l10n.insights_profile_deco_semanticLabel(
                  percentage.toStringAsFixed(1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: percentage / 100,
                    backgroundColor: Colors.green.withValues(alpha: 0.3),
                    valueColor: const AlwaysStoppedAnimation(Colors.orange),
                    minHeight: 12,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // The bar paints the deco share in orange from the leading edge
              // and leaves the no-deco remainder in green, so the legend has
              // to name them in that order. Row and LinearProgressIndicator
              // are both direction-aware, which keeps the pairing intact in
              // RTL locales.
              ExcludeSemantics(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.l10n.insights_profile_deco_decoLabel,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.orange),
                    ),
                    Text(
                      context.l10n.insights_profile_deco_noDeco,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.green),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => StatEmptyState(
          icon: Icons.error_outline,
          message: context.l10n.insights_profile_deco_error,
        ),
      ),
    );
  }

  Widget _buildDecoStat(
    BuildContext context,
    String label,
    String value,
    Color color, {
    VoidCallback? onTap,
  }) {
    final tile = Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.chevron_right,
                size: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
          ],
        ),
      ],
    );
    return Semantics(
      label: statLabel(name: label, value: value),
      button: onTap != null,
      onTap: onTap,
      child: onTap == null
          ? tile
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: tile,
              ),
            ),
    );
  }
}
