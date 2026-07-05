import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_repository_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One plan in a comparison: the aggregate, its engine outcome, and the
/// chart series derived from both.
class ComparedPlan {
  final domain.DivePlan plan;
  final PlanOutcome outcome;
  final PlanCanvasSeries series;

  const ComparedPlan({
    required this.plan,
    required this.outcome,
    required this.series,
  });
}

/// Loads and computes the plans named by a comma-joined id list. Unknown
/// ids are skipped.
final planComparisonProvider =
    FutureProvider.family<List<ComparedPlan>, String>((ref, joinedIds) async {
      final repository = ref.watch(divePlanRepositoryProvider);
      final config = ref.watch(planEngineConfigProvider);
      final engine = PlanEngine(config: config);

      final compared = <ComparedPlan>[];
      for (final id in joinedIds.split(',').where((id) => id.isNotEmpty)) {
        final plan = await repository.getPlan(id);
        if (plan == null) continue;
        final outcome = engine.compute(plan);
        compared.add(
          ComparedPlan(
            plan: plan,
            outcome: outcome,
            series: buildCanvasSeries(
              segments: plan.segments,
              outcome: outcome,
            ),
          ),
        );
      }
      return compared;
    });

/// Side-by-side comparison of 2-3 saved plans: overlaid computed profiles
/// plus a diff table of the headline numbers.
class PlanComparePage extends ConsumerWidget {
  const PlanComparePage({super.key, required this.planIds});

  final List<String> planIds;

  static const _colors = [Colors.blue, Colors.orange, Colors.purple];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comparison = ref.watch(planComparisonProvider(planIds.join(',')));
    final units = UnitFormatter(ref.watch(settingsProvider));

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.plannerCanvas_compare_title)),
      body: comparison.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (plans) => plans.length < 2
            ? Center(child: Text(context.l10n.plannerCanvas_compare_needTwo))
            : _CompareBody(plans: plans, units: units, colors: _colors),
      ),
    );
  }
}

class _CompareBody extends StatelessWidget {
  const _CompareBody({
    required this.plans,
    required this.units,
    required this.colors,
  });

  final List<ComparedPlan> plans;
  final UnitFormatter units;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SizedBox(height: 260, child: _chart(context)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          children: [
            for (final (index, compared) in plans.indexed)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: colors[index % colors.length],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    compared.plan.name,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 16),
        _diffTable(context),
      ],
    );
  }

  Widget _chart(BuildContext context) {
    final theme = Theme.of(context);
    var maxTime = 0.0;
    var maxDepth = 0.0;
    for (final compared in plans) {
      if (compared.series.maxTimeSeconds > maxTime) {
        maxTime = compared.series.maxTimeSeconds;
      }
      if (compared.series.maxDepth > maxDepth) {
        maxDepth = compared.series.maxDepth;
      }
    }
    if (maxTime <= 0) maxTime = 60;
    if (maxDepth <= 0) maxDepth = 10;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: maxTime / 60,
        // Inverted-Y depth convention: depth grows downward.
        minY: -(maxDepth * 1.1),
        maxY: 0,
        lineTouchData: const LineTouchData(enabled: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) =>
                  Text('${value.toInt()}′', style: theme.textTheme.labelSmall),
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (value, meta) => Text(
                units.formatDepth(-value, decimals: 0),
                style: theme.textTheme.labelSmall,
              ),
            ),
          ),
        ),
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          for (final (index, compared) in plans.indexed)
            LineChartBarData(
              spots: [
                for (final point in compared.series.profile)
                  FlSpot(point.timeSeconds / 60, -point.depth),
              ],
              color: colors[index % colors.length],
              barWidth: 2,
              dotData: const FlDotData(show: false),
            ),
        ],
      ),
    );
  }

  Widget _diffTable(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    String minutes(int seconds) => '${(seconds / 60).ceil()}′';

    final rows = <(String, List<String>)>[
      (
        l10n.diveLog_detail_stat_maxDepth,
        [for (final p in plans) units.formatDepth(p.outcome.maxDepth)],
      ),
      (
        l10n.divePlanner_label_runtime,
        [for (final p in plans) minutes(p.outcome.runtimeSeconds)],
      ),
      (
        l10n.divePlanner_label_tts,
        [for (final p in plans) minutes(p.outcome.ttsAtBottom)],
      ),
      (
        l10n.divePlanner_label_deco,
        [for (final p in plans) minutes(p.outcome.totalDecoSeconds)],
      ),
      (
        'CNS',
        [for (final p in plans) '${p.outcome.cnsEnd.toStringAsFixed(0)}%'],
      ),
      (
        l10n.divePlanner_label_gasConsumption,
        [
          for (final p in plans)
            units.formatVolume(
              p.outcome.tankUsages.fold<double>(
                0,
                (sum, u) => sum + u.litersUsed,
              ),
            ),
        ],
      ),
    ];

    Widget cell(String text, {bool header = false, Color? color}) => Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: header ? FontWeight.w600 : null,
            color: color,
          ),
        ),
      ),
    );

    return Column(
      children: [
        Row(
          children: [
            cell('', header: true),
            for (final (index, compared) in plans.indexed)
              cell(
                compared.plan.name,
                header: true,
                color: colors[index % colors.length],
              ),
          ],
        ),
        const Divider(height: 1),
        for (final (label, values) in rows)
          Row(
            children: [
              cell(label, header: true),
              for (final value in values) cell(value),
            ],
          ),
      ],
    );
  }
}
