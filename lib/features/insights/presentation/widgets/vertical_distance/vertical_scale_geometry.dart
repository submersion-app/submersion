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
  /// On the bar: whichever is nearer of the next landmark within 6 px of its
  /// tick and a passed landmark within 4 px, then the plain level, up to the
  /// bar's end. On a landmark's label: that landmark.
  VerticalProbe? probeAt(Offset position) {
    final direction = _legAt(position.dy);
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
    final toNext = (next.offsetPx - offset).abs();
    final snapped = layout.snap(direction, offset);
    final toSnapped = snapped == null
        ? double.infinity
        : (snapped.offsetPx - offset).abs();
    if (toNext <= 6 && toNext < toSnapped) return _forMark(direction, next);
    if (snapped != null) return _forMark(direction, snapped);
    return levelAt(position.dy);
  }

  /// The plain level at height [y] along the bar, ignoring where the pointer
  /// is sideways and any landmark: what a press-and-hold scrub reads, so a
  /// thumb that drifts off the bar keeps scrubbing. Null past the bar's end.
  VerticalProbe? levelAt(double y) {
    final offset = (y - seaY).abs();
    if (offset > layout.barPx) return null;
    final meters = layout.metersAt(offset);
    return meters > 0
        ? VerticalProbe(direction: _legAt(y), meters: meters)
        : null;
  }

  VerticalLeg _legAt(double y) =>
      y < seaY ? VerticalLeg.ascent : VerticalLeg.descent;

  VerticalProbe _forMark(VerticalLeg d, VerticalScaleMark m) => VerticalProbe(
    direction: d,
    meters: m.landmark.meters,
    landmark: m.landmark,
    ahead: !m.passed,
  );
}
