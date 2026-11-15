import 'dart:math' as math;

import 'package:submersion/features/insights/domain/vertical_distance/vertical_landmarks.dart';

/// One landmark's place on the scale (issue #4569).
class VerticalScaleMark {
  const VerticalScaleMark({
    required this.landmark,
    required this.offsetPx,
    required this.passed,
    required this.labelled,
    required this.labelOffsetPx,
  });

  final VerticalLandmark landmark;

  /// Distance of the tick from sea level, always >= 0. Which side of sea
  /// level depends on the list the mark is in.
  final double offsetPx;

  /// The diver's total has reached this landmark.
  final bool passed;

  /// The label is drawn. A thinned mark keeps its tick.
  final bool labelled;

  /// Where the label sits; equals [offsetPx] unless the label was moved
  /// toward sea level to clear the next landmark's label.
  final double labelOffsetPx;
}

/// How tall a scale for [totalMeters] must reach on its own: the larger of
/// its two next landmarks. Two cards drawn on one scale use the larger of
/// their two extents, so their bars compare at a glance.
double verticalScaleExtent(double totalMeters) {
  final total = math.max(0.0, totalMeters);
  return math.max(
    nextLandmark(VerticalLeg.ascent, total).meters,
    nextLandmark(VerticalLeg.descent, total).meters,
  );
}

/// The geometry of the scale for one total: how long the bars are and where
/// every tick and label goes. Pure, so the widget only paints it.
///
/// One linear scale serves both halves, so the mirrored bars are the same
/// length. The scale reaches the larger of the two next landmarks, plus
/// [headroom] for its label, so a diver is never more than one landmark
/// from the top and the bars always fill a good part of the card.
///
/// [VerticalScaleLayout.compute]'s `extentMeters` sizes the scale to a
/// larger extent shared with another card; it never shrinks the scale below
/// its own, so the next landmarks always fit.
class VerticalScaleLayout {
  VerticalScaleLayout._({
    required this.totalMeters,
    required this.extentMeters,
    required double pxPerMeter,
    required this.ascentMarks,
    required this.descentMarks,
  }) : _pxPerMeter = pxPerMeter;

  factory VerticalScaleLayout.compute({
    required double totalMeters,
    required double halfHeightPx,
    double? extentMeters,
    double headroom = 0.08,
    double minLabelGapPx = 18,
  }) {
    final total = math.max(0.0, totalMeters);
    final nextUp = nextLandmark(VerticalLeg.ascent, total);
    final nextDown = nextLandmark(VerticalLeg.descent, total);
    final extent = math.max(
      math.max(nextUp.meters, nextDown.meters),
      extentMeters ?? 0,
    );
    final pxPerMeter = halfHeightPx / (extent * (1 + headroom));

    final placed = _placeLabels(
      ascentPassed: passedLandmarks(VerticalLeg.ascent, total),
      ascentNext: nextUp,
      descentPassed: passedLandmarks(VerticalLeg.descent, total),
      descentNext: nextDown,
      pxPerMeter: pxPerMeter,
      minGap: minLabelGapPx,
    );

    return VerticalScaleLayout._(
      totalMeters: total,
      extentMeters: extent,
      pxPerMeter: pxPerMeter,
      ascentMarks: placed.ascent,
      descentMarks: placed.descent,
    );
  }

  final double totalMeters;

  /// The height the scale is sized to: the larger of the two next landmarks,
  /// or a larger extent shared with another card.
  final double extentMeters;

  final double _pxPerMeter;

  /// Passed landmarks ascending, then the next one, on the ascent side.
  final List<VerticalScaleMark> ascentMarks;

  /// The same for the descent side.
  final List<VerticalScaleMark> descentMarks;

  /// Length of each bar from sea level.
  double get barPx => offsetFor(totalMeters);

  double offsetFor(double meters) => meters * _pxPerMeter;

  /// Metres for a distance from sea level, clamped to 0..[totalMeters].
  double metersAt(double offsetPx) =>
      (offsetPx / _pxPerMeter).clamp(0.0, totalMeters);

  List<VerticalScaleMark> marksOn(VerticalLeg d) =>
      d == VerticalLeg.ascent ? ascentMarks : descentMarks;

  /// The passed mark on [d]'s side nearest [offsetPx] and within
  /// [tolerancePx] of it, or null.
  VerticalScaleMark? snap(
    VerticalLeg d,
    double offsetPx, {
    double tolerancePx = 4,
  }) {
    VerticalScaleMark? best;
    var bestDistance = double.infinity;
    for (final m in marksOn(d)) {
      if (!m.passed) continue;
      final distance = (m.offsetPx - offsetPx).abs();
      if (distance <= tolerancePx && distance < bestDistance) {
        best = m;
        bestDistance = distance;
      }
    }
    return best;
  }
}

/// Places both sides' ticks and decides which labels are drawn.
///
/// Labels are placed in one signed space, ascent above sea level and
/// descent below it, so two labels on opposite sides of sea level clear
/// each other too. No label sits within half a gap of sea level, where it
/// would straddle the line.
///
/// Each side's next landmark is always labelled where it is. Each side's
/// most recently passed one comes next, moved toward sea level if it would
/// crowd its next landmark's label. The rest, from both sides, are visited
/// from the farthest from sea level inward and labelled only when they
/// clear every label already placed.
({List<VerticalScaleMark> ascent, List<VerticalScaleMark> descent})
_placeLabels({
  required List<VerticalLandmark> ascentPassed,
  required VerticalLandmark ascentNext,
  required List<VerticalLandmark> descentPassed,
  required VerticalLandmark descentNext,
  required double pxPerMeter,
  required double minGap,
}) {
  final floor = minGap / 2;
  final placed = <double>[];
  bool clear(double signed) =>
      signed.abs() >= floor &&
      placed.every((p) => (p - signed).abs() >= minGap);

  final sides = [
    (passed: ascentPassed, next: ascentNext, sign: 1.0),
    (passed: descentPassed, next: descentNext, sign: -1.0),
  ];
  final labelAt = [<int, double>{}, <int, double>{}];

  for (final side in sides) {
    placed.add(side.sign * side.next.meters * pxPerMeter);
  }

  for (var s = 0; s < sides.length; s++) {
    final side = sides[s];
    if (side.passed.isEmpty) continue;
    final i = side.passed.length - 1;
    final nextOffset = side.next.meters * pxPerMeter;
    final at = math.min(
      side.passed[i].meters * pxPerMeter,
      nextOffset - minGap,
    );
    if (clear(side.sign * at)) {
      labelAt[s][i] = at;
      placed.add(side.sign * at);
    }
  }

  final rest = [
    for (var s = 0; s < sides.length; s++)
      for (var i = 0; i < sides[s].passed.length - 1; i++)
        (side: s, index: i, offset: sides[s].passed[i].meters * pxPerMeter),
  ]..sort((a, b) => b.offset.compareTo(a.offset));
  for (final m in rest) {
    final signed = sides[m.side].sign * m.offset;
    if (clear(signed)) {
      labelAt[m.side][m.index] = m.offset;
      placed.add(signed);
    }
  }

  List<VerticalScaleMark> marks(int s) {
    final side = sides[s];
    final nextOffset = side.next.meters * pxPerMeter;
    return [
      for (var i = 0; i < side.passed.length; i++)
        VerticalScaleMark(
          landmark: side.passed[i],
          offsetPx: side.passed[i].meters * pxPerMeter,
          passed: true,
          labelled: labelAt[s].containsKey(i),
          labelOffsetPx: labelAt[s][i] ?? side.passed[i].meters * pxPerMeter,
        ),
      VerticalScaleMark(
        landmark: side.next,
        offsetPx: nextOffset,
        passed: false,
        labelled: true,
        labelOffsetPx: nextOffset,
      ),
    ];
  }

  return (ascent: marks(0), descent: marks(1));
}
