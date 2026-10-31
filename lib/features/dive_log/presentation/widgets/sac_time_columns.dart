import 'dart:math' as math;

import 'package:flutter/material.dart';

/// One stretch of the dive in [SacTimeColumns].
class SacTimeColumn {
  /// Where the column starts on the time axis, in seconds from dive start.
  final int startSeconds;

  /// Sets the column's width, so a short final stretch draws narrower.
  final int durationSeconds;

  /// Height as a share of the chart, 0 to 1.
  final double heightFactor;

  /// What a screen reader announces for this column.
  final String semanticLabel;

  const SacTimeColumn({
    required this.startSeconds,
    required this.durationSeconds,
    required this.heightFactor,
    required this.semanticLabel,
  });

  int get endSeconds => startSeconds + durationSeconds;
}

/// The minute marks for a time axis of [totalMinutes], four intervals at most.
List<int> sacTimeAxisTicks(int totalMinutes) {
  const steps = [5, 10, 15, 20, 30, 60, 120, 240];
  final step = steps.firstWhere(
    (s) => totalMinutes / s <= 4,
    orElse: () => steps.last,
  );
  return [for (var tick = 0; tick <= totalMinutes; tick += step) tick];
}

/// A fixed-height column chart of gas use over the dive.
///
/// It stays the same height however long the dive is, which is why time gets
/// a chart: a five-minute grid has one row per interval as a list. Time runs
/// left to right in every locale, as it does on the profile chart. Time with
/// no column, before the first sample or across a gap in the log, stays empty
/// so that every column sits at its real time.
class SacTimeColumns extends StatelessWidget {
  static const double _chartHeight = 70;

  /// Shortest a column draws, so a near-zero rate still has a target and a
  /// mark.
  static const double _minHeightFactor = 0.03;

  final List<SacTimeColumn> columns;

  /// Height of the dashed dive-average line as a share of the chart.
  final double averageFactor;

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
    required this.activeIndex,
    required this.endLabel,
    required this.onTap,
    required this.onScrub,
    required this.onHover,
  });

  /// A column that isn't selected: opaque, so it reads the same on every card
  /// surface, and quieter than the selected column's primary.
  static Color idleColor(ColorScheme colorScheme) => Color.alphaBlend(
    colorScheme.primary.withValues(alpha: 0.45),
    colorScheme.surface,
  );

  /// The empty time ahead of the column at [index].
  int _gapBefore(int index) =>
      columns[index].startSeconds -
      (index == 0 ? 0 : columns[index - 1].endSeconds);

  /// The column at [dx], or the next one when [dx] falls in a gap.
  int _indexAt(BuildContext context, double dx) {
    final fraction = (dx / context.size!.width).clamp(0.0, 1.0);
    final seconds = fraction * columns.last.endSeconds;
    final index = columns.indexWhere((c) => seconds <= c.endSeconds);
    return index < 0 ? columns.length - 1 : index;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final idle = idleColor(colorScheme);

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: _chartHeight,
            child: MouseRegion(
              onHover: (event) =>
                  onHover(_indexAt(context, event.localPosition.dx)),
              onExit: (_) => onHover(null),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                excludeFromSemantics: true,
                onTapUp: (details) =>
                    onTap(_indexAt(context, details.localPosition.dx)),
                onHorizontalDragStart: (details) =>
                    onScrub(_indexAt(context, details.localPosition.dx)),
                onHorizontalDragUpdate: (details) =>
                    onScrub(_indexAt(context, details.localPosition.dx)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 1,
                                ),
                                child: FractionallySizedBox(
                                  alignment: Alignment.bottomCenter,
                                  heightFactor: columns[i].heightFactor.clamp(
                                    _minHeightFactor,
                                    1.0,
                                  ),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: i == activeIndex
                                          ? colorScheme.primary
                                          : idle,
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
            ),
          ),
          Divider(height: 1, thickness: 1, color: colorScheme.outlineVariant),
          const SizedBox(height: 2),
          _axis(context),
        ],
      ),
    );
  }

  Widget _axis(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final totalSeconds = columns.last.endSeconds;
    final ticks = sacTimeAxisTicks(totalSeconds ~/ 60);

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
                  tick == ticks.last && tick > 0 ? endLabel(tick) : '$tick',
                  style: style,
                ),
              ),
            ),
        ],
      ),
    );
  }
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
