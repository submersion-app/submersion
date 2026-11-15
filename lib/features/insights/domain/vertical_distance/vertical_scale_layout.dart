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

/// The geometry of the scale for one total: how long the bars are and where
/// every tick and label goes. Pure, so the widget only paints it.
///
/// One linear scale serves both halves, so the mirrored bars are the same
/// length. The scale reaches the larger of the two next landmarks, plus
/// [headroom] for its label, so a diver is never more than one landmark
/// from the top and the bars always fill a good part of the card.
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
    double headroom = 0.08,
    double minLabelGapPx = 18,
  }) {
    final total = math.max(0.0, totalMeters);
    final nextUp = nextLandmark(VerticalLeg.ascent, total);
    final nextDown = nextLandmark(VerticalLeg.descent, total);
    final extent = math.max(nextUp.meters, nextDown.meters);
    final pxPerMeter = halfHeightPx / (extent * (1 + headroom));

    List<VerticalScaleMark> marksFor(VerticalLeg d, VerticalLandmark next) =>
        _placeMarks(
          passed: passedLandmarks(d, total),
          next: next,
          pxPerMeter: pxPerMeter,
          minGap: minLabelGapPx,
        );

    return VerticalScaleLayout._(
      totalMeters: total,
      extentMeters: extent,
      pxPerMeter: pxPerMeter,
      ascentMarks: marksFor(VerticalLeg.ascent, nextUp),
      descentMarks: marksFor(VerticalLeg.descent, nextDown),
    );
  }

  final double totalMeters;

  /// The larger of the two next landmarks: the height the scale is sized to.
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

/// Places one side's ticks and decides which labels are drawn.
///
/// The next landmark is always labelled where it is. The most recently
/// passed one is always labelled too, moved toward sea level if it would
/// crowd the next one's label. The rest are visited from the largest down
/// and labelled only when they clear every label already placed.
List<VerticalScaleMark> _placeMarks({
  required List<VerticalLandmark> passed,
  required VerticalLandmark next,
  required double pxPerMeter,
  required double minGap,
}) {
  final nextOffset = next.meters * pxPerMeter;
  final placed = <double>[nextOffset];
  final labelAt = <int, double>{};

  bool clear(double at) => placed.every((p) => (p - at).abs() >= minGap);

  for (var i = passed.length - 1; i >= 0; i--) {
    final offset = passed[i].meters * pxPerMeter;
    if (i == passed.length - 1) {
      final at = math.max(0.0, math.min(offset, nextOffset - minGap));
      // Even moved, a mark at sea level can only be labelled if it clears.
      if (nextOffset - at >= minGap) {
        labelAt[i] = at;
        placed.add(at);
      }
    } else if (clear(offset)) {
      labelAt[i] = offset;
      placed.add(offset);
    }
  }

  return [
    for (var i = 0; i < passed.length; i++)
      VerticalScaleMark(
        landmark: passed[i],
        offsetPx: passed[i].meters * pxPerMeter,
        passed: true,
        labelled: labelAt.containsKey(i),
        labelOffsetPx: labelAt[i] ?? passed[i].meters * pxPerMeter,
      ),
    VerticalScaleMark(
      landmark: next,
      offsetPx: nextOffset,
      passed: false,
      labelled: true,
      labelOffsetPx: nextOffset,
    ),
  ];
}
