import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Where in the water column and when in the year a species was seen
/// (issue #5027).
///
/// The depth band says what it measures: the depths the diver photographed
/// it at when there are any (where the animal was), else the range of the
/// dives' maximum depths. The month bars count dives that saw it, across
/// every year.
class SpeciesDepthSeasonSection extends ConsumerWidget {
  const SpeciesDepthSeasonSection({
    super.key,
    required this.photoDepths,
    this.minDiveDepth,
    this.maxDiveDepth,
    required this.monthCounts,
  });

  /// Meters, from the profile match of each tagged photo.
  final List<double> photoDepths;
  final double? minDiveDepth;
  final double? maxDiveDepth;

  /// Twelve counts, January first.
  final List<int> monthCounts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (monthCounts.every((c) => c == 0)) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = ref.watch(unitFormatterProvider);
    final fromPhotos = photoDepths.isNotEmpty;
    final low = fromPhotos ? photoDepths.reduce(math.min) : minDiveDepth;
    final high = fromPhotos ? photoDepths.reduce(math.max) : maxDiveDepth;
    final hasDepth = low != null && high != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.marineLife_speciesDetail_depthSeasonTitle,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 170,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (hasDepth) ...[
                  SizedBox(
                    width: 96,
                    child: _DepthBand(
                      label: fromPhotos
                          ? l10n.marineLife_speciesDetail_photoDepths
                          : l10n.marineLife_speciesDetail_diveMaxDepth,
                      top: units.formatDepth(low, decimals: 0),
                      bottom: units.formatDepth(high, decimals: 0),
                      dots: fromPhotos
                          ? [
                              for (final d in photoDepths)
                                high == low ? 0.5 : (d - low) / (high - low),
                            ]
                          : const [],
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(child: _MonthBars(counts: monthCounts)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DepthBand extends StatelessWidget {
  const _DepthBand({
    required this.label,
    required this.top,
    required this.bottom,
    required this.dots,
  });

  final String label;
  final String top;
  final String bottom;

  /// Each dot's place on the band, 0 at the top to 1 at the bottom.
  final List<double> dots;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final small = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: small, maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Text(top, style: theme.textTheme.labelMedium),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: CustomPaint(
              size: Size.infinite,
              painter: _BandPainter(
                dots: dots,
                band: theme.colorScheme.primary.withValues(alpha: 0.25),
                dot: theme.colorScheme.primary,
              ),
            ),
          ),
        ),
        Text(bottom, style: theme.textTheme.labelMedium),
      ],
    );
  }
}

class _BandPainter extends CustomPainter {
  _BandPainter({required this.dots, required this.band, required this.dot});

  final List<double> dots;
  final Color band;
  final Color dot;

  @override
  void paint(Canvas canvas, Size size) {
    const width = 14.0;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(4, 0, width, size.height),
      const Radius.circular(7),
    );
    canvas.drawRRect(rect, Paint()..color = band);
    final paint = Paint()..color = dot;
    for (final at in dots) {
      final y = (at.clamp(0.0, 1.0)) * (size.height - 8) + 4;
      canvas.drawCircle(Offset(4 + width / 2, y), 4, paint);
    }
  }

  @override
  bool shouldRepaint(_BandPainter old) =>
      old.dots != dots || old.band != band || old.dot != dot;
}

class _MonthBars extends StatelessWidget {
  const _MonthBars({required this.counts});

  final List<int> counts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final initials = [
      for (var m = 1; m <= 12; m++)
        DateFormat('MMMMM', locale).format(DateTime(2000, m)),
    ];
    final top = counts.reduce(math.max).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.marineLife_speciesDetail_byMonth,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: BarChart(
            BarChartData(
              maxY: top,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                topTitles: const AxisTitles(),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 18,
                    getTitlesWidget: (value, meta) => SideTitleWidget(
                      meta: meta,
                      child: Text(
                        initials[value.toInt()],
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < 12; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: counts[i].toDouble(),
                        color: theme.colorScheme.primary,
                        width: 10,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(3),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
