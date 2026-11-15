import 'dart:ui';

import 'package:submersion/features/insights/domain/vertical_distance/vertical_landmarks.dart';
import 'package:submersion/features/insights/domain/vertical_distance/vertical_scale_layout.dart';
import 'package:submersion/features/insights/domain/vertical_distance/vertical_selection.dart';

/// Height of the drawn scale, in logical pixels (issue #4569).
const double kVerticalScaleHeight = 480;

/// Room on each side of sea level: half the scale, less a little padding so
/// the next landmark's label never touches the card's edge.
const double kVerticalScaleHalfHeight = kVerticalScaleHeight / 2 - 8;

/// Where the parts of the scale sit inside its box, for painting and for
/// turning a pointer position into a level. The bar is centred, so the
/// geometry is the same in either reading direction; only which side holds
/// the labels changes, and [labelsOnLeft] says which.
class VerticalScaleGeometry {
  const VerticalScaleGeometry({
    required this.width,
    required this.layout,
    required this.labelsOnLeft,
  });

  static const double barWidth = 36;

  /// How far either side of the bar still counts as pointing at it.
  static const double hitSlop = 12;

  /// Length of a landmark's tick, on the labels' side of the bar.
  static const double tickLength = 8;

  final double width;
  final VerticalScaleLayout layout;
  final bool labelsOnLeft;

  double get seaY => kVerticalScaleHeight / 2;
  double get barLeft => (width - barWidth) / 2;
  double get barRight => barLeft + barWidth;

  /// Inset of the labels' far edge, and of the headlines' near edge, from
  /// the side of the box they do not touch.
  double get columnInset => barRight + hitSlop;

  double yFor(VerticalLeg d, double offsetPx) =>
      d == VerticalLeg.ascent ? seaY - offsetPx : seaY + offsetPx;

  bool _inBarColumn(double x) =>
      x >= barLeft - hitSlop && x <= barRight + hitSlop;

  bool _inLabelColumn(double x) =>
      labelsOnLeft ? x < barLeft - hitSlop : x > barRight + hitSlop;

  /// The level under [position], in the box's own coordinates, or null when
  /// it is on nothing that has a reading.
  ///
  /// On the bar: the next landmark within 6 px of its tick, then a passed
  /// landmark within 4 px, then the plain level, up to the bar's end. On a
  /// landmark's label: that landmark.
  VerticalProbe? probeAt(Offset position) {
    final direction = position.dy < seaY
        ? VerticalLeg.ascent
        : VerticalLeg.descent;
    final offset = (position.dy - seaY).abs();
    final marks = layout.marksOn(direction);

    if (_inLabelColumn(position.dx)) {
      VerticalScaleMark? nearest;
      var distance = double.infinity;
      for (final m in marks) {
        final d = (m.labelOffsetPx - offset).abs();
        if (m.labelled && d <= 8 && d < distance) {
          nearest = m;
          distance = d;
        }
      }
      return nearest == null ? null : _forMark(direction, nearest);
    }
    if (!_inBarColumn(position.dx)) return null;

    final next = marks.last;
    if ((next.offsetPx - offset).abs() <= 6) return _forMark(direction, next);
    final snapped = layout.snap(direction, offset);
    if (snapped != null) return _forMark(direction, snapped);
    if (offset > layout.barPx) return null;
    final meters = layout.metersAt(offset);
    return meters > 0
        ? VerticalProbe(direction: direction, meters: meters)
        : null;
  }

  VerticalProbe _forMark(VerticalLeg d, VerticalScaleMark m) => VerticalProbe(
    direction: d,
    meters: m.landmark.meters,
    landmark: m.landmark,
    ahead: !m.passed,
  );
}
