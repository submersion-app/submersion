import 'dart:math' as math;
import 'dart:ui';

/// Geometry of one event label candidate, in plot-rect pixel space.
class EventLabelSpec {
  /// Pixel x of the event's vertical line within the plot rect.
  final double xPx;

  /// Pixel y of the profile depth at the event's time. Labels are anchored
  /// just below this point: the free water column under the curve, instead
  /// of the plot top where the surface (and the end-of-dive ascent tail)
  /// lives.
  final double anchorYPx;

  final double textWidth;
  final double textHeight;

  const EventLabelSpec({
    required this.xPx,
    required this.anchorYPx,
    required this.textWidth,
    required this.textHeight,
  });
}

/// Where (and whether) one event label is drawn. Placement i corresponds to
/// spec i of the input.
class EventLabelPlacement {
  /// False when no collision-free slot exists; the event's vertical line is
  /// still drawn, only the text is dropped.
  final bool showText;

  /// Pixel y of the label's top edge within the plot rect.
  final double topPx;

  /// Pixel x of the label's left edge within the plot rect. Centered on the
  /// event line by default, shifted fully to one side of the line near a
  /// plot edge, and always clamped so the text stays inside the plot even
  /// when a long localized string barely fits.
  final double leftPx;

  const EventLabelPlacement({
    required this.showText,
    required this.topPx,
    required this.leftPx,
  });
}

/// Vertical clearance between stacked labels.
const double _labelStackGap = 2;

/// Horizontal clearance between a flipped label and its event line.
const double _lineGap = 4;

/// Places event labels below their profile-depth anchor with collision
/// avoidance, replacing the previous fixed top-of-plot pinning that buried
/// the shallow end-of-dive tail under a pile of ascent-event labels.
///
/// Rules, applied per label scanning left to right:
///  - horizontal: centered on the event line; flipped fully left/right of
///    the line when the centered extent would cross a plot edge, and then
///    clamped into the plot (a string wider than the remaining space slides
///    inward rather than clipping);
///  - vertical: `anchorYPx + gap` (just below the curve point), clamped
///    into the plot; while the rect intersects an already-placed label it
///    is stepped downward, and if it runs off the bottom the search retries
///    upward from just above the anchor;
///  - if neither direction has room, the text is hidden (`showText: false`)
///    rather than stacked over the profile.
List<EventLabelPlacement> placeEventLabels(
  List<EventLabelSpec> specs, {
  required double plotWidth,
  required double plotHeight,
  double gap = 4,
}) {
  final placements = List<EventLabelPlacement?>.filled(specs.length, null);
  final placedRects = <Rect>[];

  // Scan in x order so pushed-down labels cascade predictably, but write
  // results back to the input index.
  final order = List<int>.generate(specs.length, (i) => i)
    ..sort((a, b) => specs[a].xPx.compareTo(specs[b].xPx));

  for (final i in order) {
    final spec = specs[i];

    final double desiredLeft;
    if (spec.xPx + spec.textWidth / 2 > plotWidth) {
      desiredLeft = spec.xPx - spec.textWidth - _lineGap;
    } else if (spec.xPx - spec.textWidth / 2 < 0) {
      desiredLeft = spec.xPx + _lineGap;
    } else {
      desiredLeft = spec.xPx - spec.textWidth / 2;
    }
    final left = desiredLeft
        .clamp(0.0, math.max(0.0, plotWidth - spec.textWidth))
        .toDouble();

    // Floor at 0: a transient layout can hand us a plot shorter than the
    // text, and clamp() throws when its bounds are inverted.
    final maxTop = math.max(0.0, plotHeight - spec.textHeight);
    bool collides(double top) {
      final rect = Rect.fromLTWH(left, top, spec.textWidth, spec.textHeight);
      return placedRects.any(rect.overlaps);
    }

    double? resolvedTop;
    // Downward from just below the anchor.
    var top = (spec.anchorYPx + gap).clamp(0.0, maxTop);
    while (top <= maxTop) {
      if (!collides(top)) {
        resolvedTop = top;
        break;
      }
      top += spec.textHeight + _labelStackGap;
    }
    // Upward from just above the anchor.
    if (resolvedTop == null) {
      top = (spec.anchorYPx - gap - spec.textHeight).clamp(0.0, maxTop);
      while (top >= 0) {
        if (!collides(top)) {
          resolvedTop = top;
          break;
        }
        top -= spec.textHeight + _labelStackGap;
      }
    }

    if (resolvedTop == null) {
      placements[i] = EventLabelPlacement(
        showText: false,
        topPx: (spec.anchorYPx + gap).clamp(0.0, maxTop),
        leftPx: left,
      );
    } else {
      placements[i] = EventLabelPlacement(
        showText: true,
        topPx: resolvedTop,
        leftPx: left,
      );
      placedRects.add(
        Rect.fromLTWH(left, resolvedTop, spec.textWidth, spec.textHeight),
      );
    }
  }

  return placements.cast<EventLabelPlacement>();
}
