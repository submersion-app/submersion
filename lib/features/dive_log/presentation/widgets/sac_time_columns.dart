import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/presentation/utils/chart_drag_crossing.dart';
import 'package:submersion/features/dive_log/presentation/widgets/sac_time_overlays.dart';

/// One stretch of the dive in [SacTimeColumns].
class SacTimeColumn {
  /// Where the column starts on the time axis, in seconds from dive start.
  final int startSeconds;

  /// Sets the column's width, so a short final stretch draws narrower.
  final int durationSeconds;

  /// How far the stretch strayed from the dive average, as a signed share of
  /// the plot's height: positive rises above the average line, negative
  /// hangs below it.
  final double barFactor;

  /// The column's fill. Null uses the theme's primary.
  final Color? color;

  /// What a screen reader announces for this column.
  final String semanticLabel;

  const SacTimeColumn({
    required this.startSeconds,
    required this.durationSeconds,
    required this.barFactor,
    this.color,
    required this.semanticLabel,
  });

  int get endSeconds => startSeconds + durationSeconds;
}

/// A value written at the end of one bar of [SacTimeColumns], such as `+6`.
class SacBarLabel {
  /// The column it labels.
  final int index;
  final String text;

  const SacBarLabel({required this.index, required this.text});
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

/// A compact chart of gas use over the dive, measured against the dive's own
/// average: the average runs across the plot, and each stretch rises above it
/// or hangs below it by how far it strayed, so the chart shows when the diver
/// breathed harder or easier than usual rather than repeating the average.
///
/// It stays the same height however long the dive is. Time runs left to
/// right in every locale, as it does on the profile chart. Time with no
/// column, before the first sample or across a gap in the log, stays empty so
/// that every column sits at its real time.
///
/// It spends no width on a rate axis. The stretches furthest above and below
/// the average carry their difference at the end of their bars, the average
/// line carries its own value, and the picked stretch's figures float beside
/// its bar.
class SacTimeColumns extends StatelessWidget {
  /// The plot itself, above the time axis, labels included.
  static const Key plotKey = ValueKey('sacTimeColumnsPlot');

  /// The tooltip with the picked stretch's figures.
  static const Key tooltipKey = ValueKey('sacTimeColumnsTooltip');

  /// The height the bars share, above and below the average together.
  static const double barsHeight = 64;

  /// Shortest a bar draws, so a stretch right on the average still shows.
  static const double _minBarHeight = 2;

  /// Space between a bar's end and its label.
  static const double _labelGap = 2;

  static const double _tooltipMaxWidth = 220;

  /// How far in from its end of the line the average tag may reach, for
  /// keeping a bar's label off it.
  static const double _averageTagReach = 64;

  /// How much of its color a column keeps while another one is picked, so
  /// the picked column is the only one at full strength (issue #4697).
  static const double unpickedAlpha = 0.35;

  /// Outlines the picked column as well, so the pick does not rest on color
  /// alone.
  static const double _selectedOutlineWidth = 2;

  final List<SacTimeColumn> columns;

  /// Where the average line runs, as a share of [barsHeight] from its top.
  final double baselineFactor;

  /// Names the average line, such as `avg 18`. Null leaves it unnamed.
  final String? averageLabel;

  /// Values written at the end of some bars.
  final List<SacBarLabel> barLabels;

  /// The column drawn as selected.
  final int? activeIndex;

  /// The selected column's figures, shown beside it. Null shows nothing.
  final String? activeDetails;

  /// Formats the last axis label, which also carries the unit.
  final String Function(int minutes) endLabel;

  final ValueChanged<int> onTap;
  final ValueChanged<int> onScrub;
  final ValueChanged<int?> onHover;

  /// The dive time under a hovering or dragging pointer, in seconds, then
  /// null when it leaves or lifts. Drives the profile cursor (#4423).
  final ValueChanged<int?>? onCursorSeconds;

  const SacTimeColumns({
    super.key,
    required this.columns,
    required this.baselineFactor,
    this.averageLabel,
    this.barLabels = const [],
    required this.activeIndex,
    this.activeDetails,
    required this.endLabel,
    required this.onTap,
    required this.onScrub,
    required this.onHover,
    this.onCursorSeconds,
  });

  int get _totalSeconds => columns.last.endSeconds;

  /// The empty time ahead of the column at [index].
  int _gapBefore(int index) =>
      columns[index].startSeconds -
      (index == 0 ? 0 : columns[index - 1].endSeconds);

  /// The dive time at [dx]: the plot runs linearly from 0 to the last
  /// column's end.
  double _secondsAt(double plotWidth, double dx) =>
      (dx / plotWidth).clamp(0.0, 1.0) * _totalSeconds;

  /// The column at [dx], or the next one when [dx] falls in a gap.
  int _indexAt(double plotWidth, double dx) {
    final seconds = _secondsAt(plotWidth, dx);
    final index = columns.indexWhere((c) => seconds <= c.endSeconds);
    return index < 0 ? columns.length - 1 : index;
  }

  /// Where [seconds] falls across a plot [width] wide.
  double _xAt(double width, num seconds) =>
      _totalSeconds > 0 ? width * seconds / _totalSeconds : 0;

  void _hoverAt(double plotWidth, double dx) {
    onHover(_indexAt(plotWidth, dx));
    onCursorSeconds?.call(_secondsAt(plotWidth, dx).round());
  }

  void _scrubAt(double plotWidth, double dx) {
    onScrub(_indexAt(plotWidth, dx));
    onCursorSeconds?.call(_secondsAt(plotWidth, dx).round());
  }

  /// The average line's height in the bars area.
  double get _baselineY => barsHeight * baselineFactor.clamp(0.0, 1.0);

  /// The length a column's bar draws.
  double _barLength(int index) =>
      math.max(_minBarHeight, columns[index].barFactor.abs() * barsHeight);

  bool _rises(int index) => columns[index].barFactor > 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    // Each label band holds one line of labels at any text scale.
    final band =
        MediaQuery.textScalerOf(context).scale(labelStyle?.fontSize ?? 11) *
            (labelStyle?.height ?? 1.2) +
        _labelGap;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            key: plotKey,
            height: band * 2 + barsHeight,
            child: LayoutBuilder(
              builder: (context, constraints) =>
                  _plot(theme, labelStyle, constraints.maxWidth, band),
            ),
          ),
          const SizedBox(height: 2),
          _TimeAxis(totalSeconds: _totalSeconds, endLabel: endLabel),
        ],
      ),
    );
  }

  /// The fill of the column at [index]: full strength when it is picked or
  /// nothing is, faded while another column is picked.
  Color _fill(ColorScheme colorScheme, int index) {
    final color = columns[index].color ?? colorScheme.primary;
    final faded = activeIndex != null && index != activeIndex;
    return faded ? color.withValues(alpha: unpickedAlpha) : color;
  }

  Widget _bar(ColorScheme colorScheme, int index) {
    const corner = Radius.circular(3);
    final rises = _rises(index);
    final length = _barLength(index);
    return Positioned(
      left: 0,
      right: 0,
      top: rises ? _baselineY - length : _baselineY,
      height: length,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _fill(colorScheme, index),
          border: index == activeIndex
              ? Border.all(
                  color: colorScheme.onSurface,
                  width: _selectedOutlineWidth,
                  // Centered on the edge: half inside, so a short bar keeps
                  // its color, and half in the 1 px gap, so no neighbour
                  // paints over it.
                  strokeAlign: BorderSide.strokeAlignCenter,
                )
              : null,
          borderRadius: rises
              ? const BorderRadius.vertical(top: corner)
              : const BorderRadius.vertical(bottom: corner),
        ),
      ),
    );
  }

  Widget _columns(ColorScheme colorScheme) => Row(
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
              child: Stack(children: [_bar(colorScheme, i)]),
            ),
          ),
        ),
      ],
    ],
  );

  Widget _barLabel(SacBarLabel label, TextStyle? style, double width) {
    final column = columns[label.index];
    final x = _xAt(width, column.startSeconds + column.durationSeconds / 2);
    final rises = _rises(label.index);
    final length = _barLength(label.index);
    return CustomSingleChildLayout(
      delegate: SacPinLayout(
        anchor: Offset(
          x,
          rises
              ? _baselineY - length - _labelGap
              : _baselineY + length + _labelGap,
        ),
        childAnchor: rises ? Alignment.bottomCenter : Alignment.topCenter,
      ),
      child: Text(label.text, style: style, softWrap: false),
    );
  }

  /// Whether a bar label sits within the average tag's reach of the left
  /// end of a plot [width] wide, or of the right end with [fromRight].
  bool _labelNearEnd(double width, {required bool fromRight}) =>
      barLabels.any((label) {
        if (label.index < 0 || label.index >= columns.length) return false;
        final column = columns[label.index];
        final x = _xAt(width, column.startSeconds + column.durationSeconds / 2);
        return fromRight ? x > width - _averageTagReach : x < _averageTagReach;
      });

  /// The average tag, at the left end of the line unless a bar's label sits
  /// there and the right end is clear.
  Widget _averageTag(
    ThemeData theme,
    TextStyle? style,
    String label,
    double width,
  ) {
    final right =
        _labelNearEnd(width, fromRight: false) &&
        !_labelNearEnd(width, fromRight: true);
    return CustomSingleChildLayout(
      delegate: SacPinLayout(
        anchor: Offset(right ? width : 0, _baselineY),
        childAnchor: right ? Alignment.centerRight : Alignment.centerLeft,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          // The card's own color, so the tag reads over the bars it covers.
          color: theme.cardTheme.color ?? theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(label, style: style, softWrap: false),
        ),
      ),
    );
  }

  Widget _tooltip(double width, double band, String details) {
    final column = columns[activeIndex!];
    return CustomSingleChildLayout(
      delegate: SacTooltipLayout(
        barLeft: _xAt(width, column.startSeconds),
        barRight: _xAt(width, column.endSeconds),
        centerY: barsHeight / 2,
        baselineY: _baselineY,
        rises: _rises(activeIndex!),
        // The plot's edges, label bands included, in the bars' coordinates.
        top: -band,
        bottom: barsHeight + band,
        maxWidth: _tooltipMaxWidth,
      ),
      child: SacChartTooltip(key: tooltipKey, text: details),
    );
  }

  Widget _plot(
    ThemeData theme,
    TextStyle? labelStyle,
    double width,
    double band,
  ) {
    final colorScheme = theme.colorScheme;
    final valueStyle = labelStyle?.copyWith(color: colorScheme.onSurface);
    final details = activeIndex == null ? null : activeDetails;
    return MouseRegion(
      onHover: (event) => _hoverAt(width, event.localPosition.dx),
      onExit: (event) {
        onHover(null);
        // A scrub that strays off the plot goes on until its drag ends,
        // which clears the cursor (issue #4611).
        if (!isDragCrossing(event)) onCursorSeconds?.call(null);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTapUp: (details) => onTap(_indexAt(width, details.localPosition.dx)),
        onHorizontalDragStart: (details) =>
            _scrubAt(width, details.localPosition.dx),
        onHorizontalDragUpdate: (details) =>
            _scrubAt(width, details.localPosition.dx),
        // Lifting clears the profile cursor, as it does on the profile chart;
        // the scrubbed column stays pinned in the card.
        onHorizontalDragEnd: (_) => onCursorSeconds?.call(null),
        onHorizontalDragCancel: () => onCursorSeconds?.call(null),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: band),
          child: Stack(
            fit: StackFit.expand,
            // Labels and the tooltip may reach into the label bands.
            clipBehavior: Clip.none,
            children: [
              _columns(colorScheme),
              IgnorePointer(
                child: CustomPaint(
                  painter: _BaselinePainter(
                    y: _baselineY,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              // Each column's own label already gives its rate to a screen
              // reader.
              ExcludeSemantics(
                child: IgnorePointer(
                  child: Stack(
                    fit: StackFit.expand,
                    clipBehavior: Clip.none,
                    children: [
                      for (final label in barLabels)
                        if (label.index >= 0 && label.index < columns.length)
                          _barLabel(label, valueStyle, width),
                      if (averageLabel != null)
                        _averageTag(theme, labelStyle, averageLabel!, width),
                    ],
                  ),
                ),
              ),
              if (details != null)
                IgnorePointer(child: _tooltip(width, band, details)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The time labels. Measuring them is the costly part of the chart, and the
/// profile cursor rebuilds the chart as it moves, so the marks are kept until
/// something that changes them does.
class _TimeAxis extends StatefulWidget {
  final int totalSeconds;
  final String Function(int minutes) endLabel;

  const _TimeAxis({required this.totalSeconds, required this.endLabel});

  @override
  State<_TimeAxis> createState() => _TimeAxisState();
}

class _TimeAxisState extends State<_TimeAxis> {
  Object? _measuredFor;
  List<int> _marks = const [];

  @override
  void initState() {
    super.initState();
    PaintingBinding.instance.systemFonts.addListener(_remeasure);
  }

  @override
  void dispose() {
    PaintingBinding.instance.systemFonts.removeListener(_remeasure);
    super.dispose();
  }

  /// A theme's downloaded font can arrive after the first layout.
  void _remeasure() => setState(() => _measuredFor = null);

  String _label(int tick, {required bool isLast}) =>
      isLast && tick > 0 ? widget.endLabel(tick) : '$tick';

  double _labelWidth(
    int tick,
    TextStyle? style,
    TextScaler textScaler, {
    required bool isLast,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: _label(tick, isLast: isLast),
        style: style,
      ),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  List<int> _marksFor(double width, TextStyle? style, TextScaler textScaler) {
    // The sample end label stands in for the locale.
    final inputs = (
      widget.totalSeconds,
      width,
      style,
      textScaler,
      widget.endLabel(0),
    );
    if (inputs != _measuredFor) {
      _measuredFor = inputs;
      _marks = sacTimeAxisMarks(
        totalSeconds: widget.totalSeconds,
        width: width,
        labelWidth: (tick, {required isLast}) =>
            _labelWidth(tick, style, textScaler, isLast: isLast),
      );
    }
    return _marks;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final totalSeconds = widget.totalSeconds;
    final textScaler = MediaQuery.textScalerOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final marks = _marksFor(constraints.maxWidth, style, textScaler);
        return ExcludeSemantics(
          child: Stack(
            children: [
              // An empty line gives the axis its height at any text scale.
              Text('', style: style),
              for (final tick in marks)
                Positioned.fill(
                  child: Align(
                    // Alignment rather than a pixel offset keeps the first and
                    // last labels inside the chart.
                    alignment: Alignment(
                      totalSeconds > 0 ? tick * 120 / totalSeconds - 1 : -1,
                      0,
                    ),
                    child: Text(
                      _label(tick, isLast: tick == marks.last),
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

/// The average line, the zero of the chart, which every bar starts from.
class _BaselinePainter extends CustomPainter {
  final double y;
  final Color color;

  const _BaselinePainter({required this.y, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }

  @override
  bool shouldRepaint(_BaselinePainter oldDelegate) =>
      oldDelegate.y != y || oldDelegate.color != color;
}
