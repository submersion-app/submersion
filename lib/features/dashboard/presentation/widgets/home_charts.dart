import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:submersion/core/theme/status_colors.dart';

// Small charts for the Home panels. Plain painters rather than a charting
// package: at this size a chart needs no axes, legends or touch handling,
// and every colour comes from the theme.

/// Where each of [values] is drawn in a box of [size]: scaled to fill it,
/// higher values higher (lower with [invert]). With [xs], one per value and
/// spanning a range, each point sits at its own x across the width, so
/// uneven spacing keeps its shape; otherwise the points are evenly spaced.
/// One value gives a single point at the left edge.
List<Offset> homeSparklinePoints(
  List<double> values,
  Size size, {
  List<double>? xs,
  bool invert = false,
}) {
  if (values.isEmpty) return const [];
  final lo = values.reduce(math.min);
  final hi = values.reduce(math.max);
  final span = hi - lo;
  double y(double v) {
    final t = span == 0 ? 0.5 : (v - lo) / span;
    final shown = invert ? t : 1 - t;
    return 1 + shown * (size.height - 2);
  }

  final timed = xs != null && xs.length == values.length && xs.last > xs.first;
  final step = values.length == 1 ? 0.0 : size.width / (values.length - 1);
  double x(int i) =>
      timed ? (xs[i] - xs.first) / (xs.last - xs.first) * size.width : i * step;
  return [for (var i = 0; i < values.length; i++) Offset(x(i), y(values[i]))];
}

/// A line through [values] scaled to fill the box, with a faint fill under
/// it. Nothing is drawn for an empty list; one value draws a flat line.
class HomeSparkline extends StatelessWidget {
  final List<double> values;

  /// Each value's position along the x axis (a depth profile's sample
  /// times), so unevenly spaced values keep their shape. Null spaces them
  /// evenly.
  final List<double>? xs;

  /// Draws higher values lower, as a depth profile reads.
  final bool invert;
  final bool fill;

  const HomeSparkline(
    this.values, {
    this.xs,
    this.invert = false,
    this.fill = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return CustomPaint(
      size: Size.infinite,
      painter: _SparklinePainter(
        values,
        color,
        xs: xs,
        invert: invert,
        fill: fill,
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final List<double>? xs;
  final Color color;
  final bool invert;
  final bool fill;

  _SparklinePainter(
    this.values,
    this.color, {
    required this.xs,
    required this.invert,
    required this.fill,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || size.isEmpty) return;
    final points = homeSparklinePoints(values, size, xs: xs, invert: invert);
    final line = Path()..moveTo(points.first.dx, points.first.dy);
    if (points.length == 1) {
      line.lineTo(size.width, points.first.dy);
    } else {
      for (final p in points.skip(1)) {
        line.lineTo(p.dx, p.dy);
      }
    }
    if (fill) {
      final area = Path.from(line)
        ..lineTo(size.width, invert ? 0 : size.height)
        ..lineTo(0, invert ? 0 : size.height)
        ..close();
      canvas.drawPath(area, Paint()..color = color.withValues(alpha: 0.16));
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.values != values ||
      old.xs != xs ||
      old.color != color ||
      old.invert != invert ||
      old.fill != fill;
}

/// Vertical bars for [values], with an optional label under each.
class HomeBars extends StatelessWidget {
  final List<double> values;
  final List<String> labels;

  /// A colour per bar, where the colour means something (a depth band's
  /// shade). Null draws every bar in the theme's primary colour.
  final List<Color>? colors;

  const HomeBars(this.values, {this.labels = const [], this.colors, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontSize: 9,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: CustomPaint(
            size: Size.infinite,
            painter: _BarsPainter(
              values,
              theme.colorScheme.primary,
              colors: colors,
            ),
          ),
        ),
        if (labels.isNotEmpty) ...[
          const SizedBox(height: 2),
          // Left to right in every language, as the painter draws the bars:
          // a row mirrored for a right-to-left locale would put each label
          // under the wrong bar.
          Row(
            textDirection: TextDirection.ltr,
            children: [
              for (final l in labels)
                Expanded(
                  child: Text(
                    l,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    textAlign: TextAlign.center,
                    style: labelStyle,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _BarsPainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final List<Color>? colors;

  _BarsPainter(this.values, this.color, {this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || size.isEmpty) return;
    final hi = values.reduce(math.max);
    final slot = size.width / values.length;
    final gap = math.min(4.0, slot * 0.25);
    final perBar = colors;
    for (var i = 0; i < values.length; i++) {
      final h = hi <= 0 ? 0.0 : values[i] / hi * size.height;
      if (h <= 0) continue;
      final paint = Paint()
        ..color = perBar != null && i < perBar.length ? perBar[i] : color;
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(i * slot + gap / 2, size.height - h, slot - gap, h),
          topLeft: const Radius.circular(2),
          topRight: const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      old.values != values ||
      old.color != color ||
      !listEquals(old.colors, colors);
}

enum HomeBarTone { accent, ok, warn, alert }

/// A label and value on one line with a thin bar under them showing
/// [fraction] (0 to 1) of the width; no bar when [fraction] is null.
class HomeBarRow extends StatelessWidget {
  final String label;
  final String value;
  final double? fraction;
  final HomeBarTone tone;

  /// The bar's own colour, where it means something (a gas's colour); it
  /// replaces [tone]'s.
  final Color? color;

  const HomeBarRow({
    required this.label,
    required this.value,
    required this.fraction,
    this.tone = HomeBarTone.accent,
    this.color,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = StatusColors.of(context);
    final barColor =
        color ??
        switch (tone) {
          HomeBarTone.accent => scheme.primary,
          HomeBarTone.ok => status.ok.outline,
          HomeBarTone.warn => status.warn.outline,
          HomeBarTone.alert => status.alert.outline,
        };
    final text = theme.textTheme.bodySmall;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // The label takes what the value leaves; the value keeps its own
          // width, up to 60% of the row, so it sits at the right edge.
          LayoutBuilder(
            builder: (context, box) => Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text,
                  ),
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: box.maxWidth * 0.6),
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: text?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (fraction case final f?) ...[
            const SizedBox(height: 3),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: f.isNaN ? 0 : f.clamp(0.0, 1.0),
                minHeight: 4,
                color: barColor,
                backgroundColor: scheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One cell per day from [from] to [to], weeks as columns (Monday on top),
/// shaded by how many dives the day had. When the box is too narrow for
/// every week at [minCell] pixels a cell, the oldest weeks are left out.
class HomeDayGrid extends StatelessWidget {
  final Map<DateTime, int> counts;
  final DateTime from;
  final DateTime to;

  static const double minCell = 6;
  static const double gap = 2;

  const HomeDayGrid({
    required this.counts,
    required this.from,
    required this.to,
    super.key,
  });

  static DateTime _monday(DateTime d) =>
      DateTime(d.year, d.month, d.day - (d.weekday - 1));

  static int _totalWeeks(DateTime from, DateTime to) =>
      (_monday(to).difference(_monday(from)).inDays / 7).round() + 1;

  /// How many week columns fit in [width], at most the whole range.
  static int weeksShown(DateTime from, DateTime to, double width) => math.max(
    1,
    math.min(_totalWeeks(from, to), ((width + gap) / (minCell + gap)).floor()),
  );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final weeks = weeksShown(from, to, constraints.maxWidth);
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _DayGridPainter(
            counts: counts,
            lastMonday: _monday(to),
            to: to,
            from: from,
            weeks: weeks,
            empty: scheme.outlineVariant.withValues(alpha: 0.5),
            filled: scheme.primary,
          ),
        );
      },
    );
  }
}

class _DayGridPainter extends CustomPainter {
  final Map<DateTime, int> counts;
  final DateTime lastMonday;
  final DateTime from;
  final DateTime to;
  final int weeks;
  final Color empty;
  final Color filled;

  _DayGridPainter({
    required this.counts,
    required this.lastMonday,
    required this.from,
    required this.to,
    required this.weeks,
    required this.empty,
    required this.filled,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    const gap = HomeDayGrid.gap;
    final cell = math.min(
      (size.width + gap) / weeks - gap,
      (size.height + gap) / 7 - gap,
    );
    if (cell <= 0) return;
    final first = DateTime(from.year, from.month, from.day);
    final last = DateTime(to.year, to.month, to.day);
    for (var w = 0; w < weeks; w++) {
      final monday = DateTime(
        lastMonday.year,
        lastMonday.month,
        lastMonday.day - 7 * (weeks - 1 - w),
      );
      for (var d = 0; d < 7; d++) {
        final day = DateTime(monday.year, monday.month, monday.day + d);
        if (day.isBefore(first) || day.isAfter(last)) continue;
        final n = counts[day] ?? 0;
        final paint = Paint()
          ..color = n == 0
              ? empty
              : filled.withValues(alpha: n >= 3 ? 1 : (n == 2 ? 0.75 : 0.5));
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * (cell + gap), d * (cell + gap), cell, cell),
            Radius.circular(cell / 5),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DayGridPainter old) =>
      old.counts != counts ||
      old.weeks != weeks ||
      old.filled != filled ||
      old.empty != empty ||
      old.from != from ||
      old.to != to ||
      old.lastMonday != lastMonday;
}
