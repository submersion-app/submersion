import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:submersion/features/dive_log/presentation/widgets/sac_segment_colors.dart';

/// One stretch of the dive in [SacTimeColumns].
class SacTimeColumn {
  /// Where the column starts on the time axis, in seconds from dive start.
  final int startSeconds;

  /// Sets the column's width, so a short final stretch draws narrower.
  final int durationSeconds;

  /// Height as a share of the chart, 0 to 1.
  final double heightFactor;

  /// Drawn at full strength when selected. Null uses the theme's primary.
  final Color? color;

  /// What a screen reader announces for this column.
  final String semanticLabel;

  const SacTimeColumn({
    required this.startSeconds,
    required this.durationSeconds,
    required this.heightFactor,
    this.color,
    required this.semanticLabel,
  });

  int get endSeconds => startSeconds + durationSeconds;
}

/// A labelled line on the rate axis of [SacTimeColumns].
class SacRateTick {
  /// Height as a share of the chart, 0 to 1.
  final double factor;
  final String label;

  const SacRateTick({required this.factor, required this.label});
}

/// The finest time marks whose labels clear each other across [width].
///
/// Labels are measured rather than assumed, since a translated unit or larger
/// text changes how many fit. [labelWidth] gives the width of the label at a
/// mark, which is wider on the last mark, where it carries the unit. Five
/// minutes is the finest step, the width of a full column.
List<int> sacTimeAxisMarks({
  required int totalSeconds,
  required double width,
  required double Function(int tick, {required bool isLast}) labelWidth,
}) {
  const steps = [5, 10, 15, 20, 30, 60, 120, 240];
  final totalMinutes = totalSeconds ~/ 60;
  List<int> ticks(int step) => [
    for (var tick = 0; tick <= totalMinutes; tick += step) tick,
  ];
  return steps
      .map(ticks)
      .firstWhere(
        (marks) => _labelsClear(marks, totalSeconds, width, labelWidth),
        orElse: () => ticks(steps.last),
      );
}

bool _labelsClear(
  List<int> ticks,
  int totalSeconds,
  double width,
  double Function(int tick, {required bool isLast}) labelWidth,
) {
  if (ticks.length < 2) return true;
  const minGap = 8.0;
  var previousEnd = double.negativeInfinity;
  for (final (index, tick) in ticks.indexed) {
    final labelSize = labelWidth(tick, isLast: index == ticks.length - 1);
    // Where [SacTimeColumns] puts it: inside the chart at either end.
    final start = tick * 60 / totalSeconds * (width - labelSize);
    if (start < previousEnd + minGap) return false;
    previousEnd = start + labelSize;
  }
  return true;
}

/// A fixed-height column chart of gas use over the dive.
///
/// It stays the same height however long the dive is, which is why time gets
/// a chart: a five-minute grid has one row per interval as a list. Time runs
/// left to right in every locale, as it does on the profile chart. Time with
/// no column, before the first sample or across a gap in the log, stays empty
/// so that every column sits at its real time.
///
/// The time axis fits as many marks as the width allows, and the rate axis
/// labels the gridlines behind the columns.
class SacTimeColumns extends StatelessWidget {
  /// The plot itself, right of the rate axis and above the time axis.
  static const Key plotKey = ValueKey('sacTimeColumnsPlot');

  static const double _chartHeight = 96;
  static const double _rateAxisGap = 6;

  /// Shortest a column draws, so a near-zero rate still has a target and a
  /// mark.
  static const double _minHeightFactor = 0.03;

  final List<SacTimeColumn> columns;

  /// Height of the dashed dive-average line as a share of the chart.
  final double averageFactor;

  /// The labelled lines of the rate axis. Empty leaves the axis off.
  final List<SacRateTick> rateTicks;

  /// The column drawn as selected.
  final int? activeIndex;

  /// Formats the last axis label, which also carries the unit.
  final String Function(int minutes) endLabel;

  final ValueChanged<int> onTap;
  final ValueChanged<int> onScrub;
  final ValueChanged<int?> onHover;

  const SacTimeColumns({
    super.key,
    required this.columns,
    required this.averageFactor,
    this.rateTicks = const [],
    required this.activeIndex,
    required this.endLabel,
    required this.onTap,
    required this.onScrub,
    required this.onHover,
  });

  /// The empty time ahead of the column at [index].
  int _gapBefore(int index) =>
      columns[index].startSeconds -
      (index == 0 ? 0 : columns[index - 1].endSeconds);

  /// The column at [dx], or the next one when [dx] falls in a gap.
  int _indexAt(double plotWidth, double dx) {
    final fraction = (dx / plotWidth).clamp(0.0, 1.0);
    final seconds = fraction * columns.last.endSeconds;
    final index = columns.indexWhere((c) => seconds <= c.endSeconds);
    return index < 0 ? columns.length - 1 : index;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (rateTicks.isNotEmpty) ...[
            _RateAxis(ticks: rateTicks, height: _chartHeight),
            const SizedBox(width: _rateAxisGap),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  key: plotKey,
                  height: _chartHeight,
                  child: LayoutBuilder(
                    builder: (context, constraints) =>
                        _plot(theme, constraints.maxWidth),
                  ),
                ),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: colorScheme.outlineVariant,
                ),
                const SizedBox(height: 2),
                _axis(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _plot(ThemeData theme, double width) {
    final colorScheme = theme.colorScheme;
    return MouseRegion(
      onHover: (event) => onHover(_indexAt(width, event.localPosition.dx)),
      onExit: (_) => onHover(null),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTapUp: (details) => onTap(_indexAt(width, details.localPosition.dx)),
        onHorizontalDragStart: (details) =>
            onScrub(_indexAt(width, details.localPosition.dx)),
        onHorizontalDragUpdate: (details) =>
            onScrub(_indexAt(width, details.localPosition.dx)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _GridlinesPainter(
                factors: [for (final tick in rateTicks) tick.factor],
                color: colorScheme.outlineVariant,
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < columns.length; i++) ...[
                  if (_gapBefore(i) > 0) Spacer(flex: _gapBefore(i)),
                  Expanded(
                    // Room for a zero-length stretch.
                    flex: math.max(1, columns[i].durationSeconds),
                    child: Semantics(
                      container: true,
                      label: columns[i].semanticLabel,
                      selected: i == activeIndex,
                      onTap: () => onTap(i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1),
                        child: FractionallySizedBox(
                          alignment: Alignment.bottomCenter,
                          heightFactor: columns[i].heightFactor.clamp(
                            _minHeightFactor,
                            1.0,
                          ),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: _columnColor(i, theme),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            IgnorePointer(
              child: CustomPaint(
                painter: _AverageLinePainter(
                  factor: averageFactor,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _columnColor(int index, ThemeData theme) {
    final hue = columns[index].color ?? theme.colorScheme.primary;
    return index == activeIndex ? hue : SacSegmentColors.idle(hue, theme);
  }

  Widget _axis(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final totalSeconds = columns.last.endSeconds;
    final textScaler = MediaQuery.textScalerOf(context);

    String label(int tick, {required bool isLast}) =>
        isLast && tick > 0 ? endLabel(tick) : '$tick';

    double labelWidth(int tick, {required bool isLast}) {
      final painter = TextPainter(
        text: TextSpan(
          text: label(tick, isLast: isLast),
          style: style,
        ),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final ticks = sacTimeAxisMarks(
          totalSeconds: totalSeconds,
          width: constraints.maxWidth,
          labelWidth: labelWidth,
        );
        return ExcludeSemantics(
          child: Stack(
            children: [
              // An empty line gives the axis its height at any text scale.
              Text('', style: style),
              for (final tick in ticks)
                Positioned.fill(
                  child: Align(
                    // Alignment rather than a pixel offset keeps the first and
                    // last labels inside the chart.
                    alignment: Alignment(
                      totalSeconds > 0 ? tick * 120 / totalSeconds - 1 : -1,
                      0,
                    ),
                    child: Text(
                      label(tick, isLast: tick == ticks.last),
                      style: style,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// The rate labels, each level with its gridline. The widest sets the width.
class _RateAxis extends StatelessWidget {
  final List<SacRateTick> ticks;
  final double height;

  const _RateAxis({required this.ticks, required this.height});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    // Each column's own label already gives its rate to a screen reader.
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            for (final tick in ticks)
              Align(
                // Alignment rather than a pixel offset keeps the top and
                // bottom labels inside the chart.
                alignment: Alignment(1, 1 - 2 * tick.factor),
                widthFactor: 1,
                child: Text(tick.label, style: style, softWrap: false),
              ),
          ],
        ),
      ),
    );
  }
}

class _GridlinesPainter extends CustomPainter {
  final List<double> factors;
  final Color color;

  const _GridlinesPainter({required this.factors, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (final factor in factors) {
      // The chart's baseline already marks zero.
      if (factor <= 0) continue;
      final y = math.max(0.5, size.height * (1 - factor));
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridlinesPainter oldDelegate) =>
      !listEquals(oldDelegate.factors, factors) || oldDelegate.color != color;
}

class _AverageLinePainter extends CustomPainter {
  static const double _dash = 4;
  static const double _gap = 3;

  final double factor;
  final Color color;

  const _AverageLinePainter({required this.factor, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * (1 - factor.clamp(0.0, 1.0));
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += _dash + _gap) {
      canvas.drawLine(
        Offset(x, y),
        Offset(math.min(x + _dash, size.width), y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_AverageLinePainter oldDelegate) =>
      oldDelegate.factor != factor || oldDelegate.color != color;
}
