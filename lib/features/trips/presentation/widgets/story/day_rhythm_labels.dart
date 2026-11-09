import 'dart:math' as math;

import 'package:flutter/material.dart';

/// What a label under the day timeline marks.
enum RhythmLabelKind { sunrise, sunset, tick }

/// A label to place: its kind, where on the day it marks (0 to 1), and its
/// measured width in logical pixels.
typedef RhythmLabelSpec = ({
  RhythmLabelKind kind,
  double centerFraction,
  double width,
});

/// A label that found room: its position in the input, and its left edge.
typedef PlacedRhythmLabel = ({int index, RhythmLabelSpec spec, double left});

/// A label to draw under the day timeline.
typedef RhythmLabel = ({
  RhythmLabelKind kind,
  double centerFraction,
  String text,
});

/// Places the labels under a day timeline [barWidth] wide so none overprints
/// another (issue #4375).
///
/// The sunrise is placed first, then the sunset, each centred on its moment
/// and kept inside the bar. A sunset that would overlap the sunrise moves
/// clear of it, on the side its own moment lies, and is dropped when there
/// is still no room. Hour ticks come last and are dropped wherever they
/// would overlap a placed label. A label wider than the bar is dropped. The
/// result keeps the input order.
List<PlacedRhythmLabel> placeRhythmLabels(
  List<RhythmLabelSpec> specs,
  double barWidth, {
  double gap = 4,
}) {
  int rank(RhythmLabelKind kind) => switch (kind) {
    RhythmLabelKind.sunrise => 0,
    RhythmLabelKind.sunset => 1,
    RhythmLabelKind.tick => 2,
  };
  final order = List.generate(specs.length, (i) => i)
    ..sort((a, b) {
      final byRank = rank(specs[a].kind).compareTo(rank(specs[b].kind));
      return byRank != 0 ? byRank : a.compareTo(b);
    });

  double clampLeft(double left, double width) =>
      left.clamp(0.0, math.max(0.0, barWidth - width));
  bool clashes(double left, double width, int other, double otherLeft) =>
      left < otherLeft + specs[other].width + gap &&
      otherLeft < left + width + gap;

  final lefts = <int, double>{};
  for (final i in order) {
    final spec = specs[i];
    // A label wider than the whole bar (large text on a narrow bar) has no
    // place to go; drawing it would run past the bar's end.
    if (spec.width > barWidth) continue;
    final center = spec.centerFraction * barWidth;
    var left = clampLeft(center - spec.width / 2, spec.width);
    if (spec.kind != RhythmLabelKind.tick) {
      for (final MapEntry(key: j, value: otherLeft) in lefts.entries) {
        if (!clashes(left, spec.width, j, otherLeft)) continue;
        final otherCenter = specs[j].centerFraction * barWidth;
        left = clampLeft(
          center >= otherCenter
              ? otherLeft + specs[j].width + gap
              : otherLeft - gap - spec.width,
          spec.width,
        );
      }
    }
    final fits = lefts.entries.every(
      (other) => !clashes(left, spec.width, other.key, other.value),
    );
    if (fits) lefts[i] = left;
  }

  return [
    for (var i = 0; i < specs.length; i++)
      if (lefts[i] case final left?) (index: i, spec: specs[i], left: left),
  ];
}

/// The row of time labels under the day timeline: sunrise and sunset with
/// their icons, and hour ticks.
///
/// Decorative for assistive technology: the bar's own semantics label
/// speaks the sun times.
class DayRhythmLabelRow extends StatelessWidget {
  final List<RhythmLabel> labels;
  final TextStyle? tickStyle;
  final TextStyle? sunStyle;

  const DayRhythmLabelRow({
    super.key,
    required this.labels,
    this.tickStyle,
    this.sunStyle,
  });

  static const double _iconGap = 2;

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);
    final baseStyle = Theme.of(context).textTheme.labelSmall;
    TextStyle? styleFor(RhythmLabelKind kind) =>
        baseStyle?.merge(kind == RhythmLabelKind.tick ? tickStyle : sunStyle);

    final measured = [
      for (final label in labels)
        _measure(label, styleFor(label.kind), textScaler, textDirection),
    ];
    final lineHeight = measured.fold<double>(
      0,
      (height, m) => math.max(height, m.height),
    );

    return ExcludeSemantics(
      child: SizedBox(
        height: lineHeight,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final specs = [
              for (var i = 0; i < labels.length; i++)
                (
                  kind: labels[i].kind,
                  centerFraction: labels[i].centerFraction,
                  width: measured[i].width,
                ),
            ];
            final placed = placeRhythmLabels(specs, constraints.maxWidth);
            return Stack(
              clipBehavior: Clip.none,
              children: [
                for (final p in placed)
                  Positioned(
                    left: p.left,
                    top: 0,
                    child: _label(
                      labels[p.index],
                      styleFor(p.spec.kind),
                      measured[p.index].iconSize,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _label(RhythmLabel label, TextStyle? style, double iconSize) {
    final text = Text(
      label.text,
      style: style,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.visible,
    );
    final icon = _iconFor(label.kind);
    if (icon == null) return text;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: iconSize, color: style?.color),
        const SizedBox(width: _iconGap),
        text,
      ],
    );
  }

  static IconData? _iconFor(RhythmLabelKind kind) => switch (kind) {
    RhythmLabelKind.sunrise => Icons.wb_twilight,
    RhythmLabelKind.sunset => Icons.nights_stay_outlined,
    RhythmLabelKind.tick => null,
  };

  static ({double width, double height, double iconSize}) _measure(
    RhythmLabel label,
    TextStyle? style,
    TextScaler textScaler,
    TextDirection textDirection,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: label.text, style: style),
      textDirection: textDirection,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();
    final iconSize = textScaler.scale(style?.fontSize ?? 11);
    final hasIcon = _iconFor(label.kind) != null;
    final result = (
      width: painter.width + (hasIcon ? iconSize + _iconGap : 0),
      height: math.max(painter.height, hasIcon ? iconSize : 0.0),
      iconSize: iconSize,
    );
    painter.dispose();
    return result;
  }
}
