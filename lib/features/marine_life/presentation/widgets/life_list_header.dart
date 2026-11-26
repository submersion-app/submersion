import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:submersion/features/marine_life/domain/life_list_summary.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Species page header (issue #5027): how many species the diver has
/// seen, how many are new this year, and how the life list has grown. A
/// chip filters to the species that still have no picture.
/// Height of the header tiles at the default text size.
const _tileHeight = 76.0;

class LifeListHeader extends StatelessWidget {
  const LifeListHeader({
    super.key,
    required this.summary,
    required this.year,
    required this.withoutPhoto,
    required this.noPhotoFilterOn,
    required this.onNoPhotoFilter,
  });

  final LifeListSummary summary;
  final int year;
  final int withoutPhoto;
  final bool noPhotoFilterOn;
  final ValueChanged<bool> onNoPhotoFilter;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            // Fixed rather than intrinsic: the growth chart lays itself out
            // and cannot report an intrinsic height. Scales with the text.
            height: MediaQuery.textScalerOf(context).scale(_tileHeight),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _FigureTile(
                    label: l10n.marineLife_speciesPage_headerSpecies,
                    value: '${summary.total}',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _FigureTile(
                    label: l10n.marineLife_speciesPage_headerNewIn('$year'),
                    value: '${summary.newThisYear}',
                  ),
                ),
                if (summary.growth.length >= 2) ...[
                  const SizedBox(width: 8),
                  Expanded(child: _GrowthTile(summary: summary)),
                ],
              ],
            ),
          ),
          // Kept while the filter is on, so it can always be turned off.
          if (withoutPhoto > 0 || noPhotoFilterOn) ...[
            const SizedBox(height: 8),
            FilterChip(
              key: const ValueKey('species_no_photo_chip'),
              avatar: const Icon(Icons.hide_image_outlined, size: 18),
              label: Text(
                l10n.marineLife_speciesPage_withoutPhoto(withoutPhoto),
              ),
              selected: noPhotoFilterOn,
              onSelected: onNoPhotoFilter,
            ),
          ],
        ],
      ),
    );
  }
}

class _FigureTile extends StatelessWidget {
  const _FigureTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(value, style: theme.textTheme.headlineSmall),
          ],
        ),
      ),
    );
  }
}

class _GrowthTile extends StatelessWidget {
  const _GrowthTile({required this.summary});

  final LifeListSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final first = summary.growth.first.date.millisecondsSinceEpoch;
    final spots = [
      for (final point in summary.growth)
        FlSpot(
          (point.date.millisecondsSinceEpoch - first) / 86400000,
          point.cumulative.toDouble(),
        ),
    ];
    return Semantics(
      label: context.l10n.marineLife_speciesPage_headerGrowth,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: ExcludeSemantics(
            child: LineChart(
              LineChartData(
                minY: 0,
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineTouchData: const LineTouchData(enabled: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isStepLineChart: true,
                    color: theme.colorScheme.primary,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: theme.colorScheme.primary.withValues(alpha: 0.15),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
