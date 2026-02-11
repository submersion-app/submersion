import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/accessibility/semantic_helpers.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_providers.dart';
import 'package:submersion/features/statistics/presentation/widgets/stat_charts.dart';
import 'package:submersion/features/statistics/presentation/widgets/stat_section_card.dart';
import 'package:submersion/l10n/l10n_extension.dart';

class StatisticsProfilePage extends ConsumerWidget {
  final bool embedded;

  const StatisticsProfilePage({super.key, this.embedded = false});

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
          _buildTimeAtDepthSection(context, ref),
          const SizedBox(height: 16),
          _buildDecoSection(context, ref),
        ],
      ),
    );

    if (embedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.statistics_profile_appBar_title)),
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
      title: context.l10n.statistics_profile_ascentDescent_title,
      subtitle: context.l10n.statistics_profile_ascentDescent_subtitle,
      child: ratesAsync.when(
        data: (data) {
          if (data.avgAscent == null && data.avgDescent == null) {
            return StatEmptyState(
              icon: Icons.trending_up,
              message: context.l10n.statistics_profile_ascentDescent_empty,
            );
          }

          return Row(
            children: [
              if (data.avgAscent != null)
                Expanded(
                  child: _buildRateStat(
                    context,
                    context.l10n.statistics_profile_avgAscent,
                    '${units.convertDepth(data.avgAscent!).toStringAsFixed(1)} ${units.depthSymbol}/min',
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
                    context.l10n.statistics_profile_avgDescent,
                    '${units.convertDepth(data.avgDescent!).toStringAsFixed(1)} ${units.depthSymbol}/min',
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
          message: context.l10n.statistics_profile_ascentDescent_error,
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

  Widget _buildTimeAtDepthSection(BuildContext context, WidgetRef ref) {
    final depthRangesAsync = ref.watch(timeAtDepthRangesProvider);

    return StatSectionCard(
      title: context.l10n.statistics_profile_timeAtDepth_title,
      subtitle: context.l10n.statistics_profile_timeAtDepth_subtitle,
      child: depthRangesAsync.when(
        data: (data) {
          if (data.isEmpty) {
            return StatEmptyState(
              icon: Icons.layers,
              message: context.l10n.statistics_profile_timeAtDepth_empty,
            );
          }
          return CategoryBarChart(
            data: data.map((d) => (label: d.range, count: d.minutes)).toList(),
            barColor: Colors.indigo,
            valueFormatter: (value) =>
                context.l10n.statistics_profile_timeAtDepth_valueFormat(value),
          );
        },
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => StatEmptyState(
          icon: Icons.error_outline,
          message: context.l10n.statistics_profile_timeAtDepth_error,
        ),
      ),
    );
  }

  Widget _buildDecoSection(BuildContext context, WidgetRef ref) {
    final decoAsync = ref.watch(decoObligationStatsProvider);

    return StatSectionCard(
      title: context.l10n.statistics_profile_deco_title,
      subtitle: context.l10n.statistics_profile_deco_subtitle,
      child: decoAsync.when(
        data: (data) {
          if (data.totalCount == 0) {
            return StatEmptyState(
              icon: Icons.stop_circle,
              message: context.l10n.statistics_profile_deco_empty,
            );
          }

          final percentage = data.decoCount / data.totalCount * 100;

          return Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildDecoStat(
                    context,
                    context.l10n.statistics_profile_deco_decoDives,
                    data.decoCount.toString(),
                    Colors.orange,
                  ),
                  _buildDecoStat(
                    context,
                    context.l10n.statistics_profile_deco_noDeco,
                    (data.totalCount - data.decoCount).toString(),
                    Colors.green,
                  ),
                  _buildDecoStat(
                    context,
                    context.l10n.statistics_profile_deco_decoRate,
                    '${percentage.toStringAsFixed(1)}%',
                    Colors.blue,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Semantics(
                label: context.l10n.statistics_profile_deco_semanticLabel(
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
              ExcludeSemantics(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.l10n.statistics_profile_deco_noDeco,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.green),
                    ),
                    Text(
                      context.l10n.statistics_profile_deco_decoLabel,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.orange),
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
          message: context.l10n.statistics_profile_deco_error,
        ),
      ),
    );
  }

  Widget _buildDecoStat(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    return Semantics(
      label: statLabel(name: label, value: value),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
    );
  }
}
