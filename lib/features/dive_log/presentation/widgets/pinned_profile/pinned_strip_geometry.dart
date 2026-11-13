import 'dart:ui';

/// Height of the pinned profile strip, all curve: its values float in a
/// tooltip below it while it is scrubbed (issue #4509).
const double kPinnedStripHeight = 44;

/// The shortest the squashed chart's plot gets, about the strip's own curve,
/// so it is still a readable chart when the strip takes over from it.
const double kMinPlotHeight = 48;

/// The squash range used until the chart's plot has been measured.
const double kSquashRange = 100;

/// How far the card can squash: the plot's resting height down to
/// [kMinPlotHeight]. Measured, since the axes and legend around the plot
/// vary with the chart's settings and the window.
double squashRangeFor({required double restPlotHeight}) =>
    (restPlotHeight - kMinPlotHeight).clamp(0.0, double.infinity);

/// How far the pinned card has squashed, from 0 to [range]. The squash
/// starts the moment [card]'s top (relative to the viewport's) passes the
/// viewport's, and the chart's plot takes all of it, its axes, grid and
/// lines intact.
///
/// It is one motion with the slide ([slideDepth]): the scroll is shared
/// between them in a fixed ratio, so the plot shortens while the card moves
/// up, both finishing as the plot, [plotTop] below the card's top, reaches
/// the top of the page. Neither starts or stops on its own.
double squashDepth({
  required Rect card,
  double range = kSquashRange,
  double plotTop = 0,
}) {
  final scrolled = -card.top;
  if (scrolled <= 0) return 0;
  final together = range + plotTop;
  if (together <= 0) return 0;
  return range * (scrolled / together).clamp(0.0, 1.0);
}

/// How far the pinned card has slid up: whatever of the scroll the squash
/// ([squashDepth]) has not taken. The card leaves the top as it naturally
/// would, header first.
double slideDepth({
  required Rect card,
  double range = kSquashRange,
  double plotTop = 0,
}) {
  final scrolled = (-card.top).clamp(0.0, double.infinity);
  return scrolled - squashDepth(card: card, range: range, plotTop: plotTop);
}

/// The share of the squash-and-slide after which the strip starts to fade
/// in. The fade has to be over by the end of it ([condenseFadeEnd]), so an
/// early start gives it a long stretch of scroll to spread over.
const double kHandOverOverlap = 0.2;

/// How far the pinned copy has zoomed out from the full card's zoom window
/// to the whole dive, from 0 to 1: in step with the squash and slide, so it
/// is all the way out as the plot reaches the top, [plotAtTop] px past the
/// card's top, where the strip has taken over.
double zoomOutProgress({required Rect card, required double plotAtTop}) {
  if (plotAtTop <= 0) return 1;
  return (-card.top / plotAtTop).clamp(0.0, 1.0);
}

/// How far the card has handed over to the strip, from 0 to 1.
///
/// [card] is the card's rect relative to the top of the scroll viewport. The
/// hand-over starts once the card has scrolled [start] past the top (the
/// squash, then the slide that brings its plot to the top) and completes as
/// the card's bottom reaches the strip's, so scrolling slowly plays it
/// slowly and scrolling back reverses it.
double condenseProgress({required Rect card, double start = kSquashRange}) {
  final past = -card.top - start;
  if (past <= 0) return 0;
  final travel = card.height - start - kPinnedStripHeight;
  if (travel <= 0) return 1;
  return (past / travel).clamp(0.0, 1.0);
}

/// Where, as a share of the hand-over ([condenseProgress]), the strip's
/// background has fully faded in over the card: the moment the card's plot
/// reaches the top of the page, [plotAtTop] px past the card's top.
///
/// Until then the strip's depth line sits exactly on the chart's, so only
/// one line is seen. Past it the card slides its plot up out of view, so
/// the full chart has to be gone by then, or the data on it would be seen
/// leaving the view; the strip alone carries the line on, below the top
/// ([PlotMapping.keptInView]). The fade follows the scroll position, so the
/// same point is where the chart starts coming back when scrolling up.
double condenseFadeEnd({
  required double start,
  required double plotAtTop,
  required double cardHeight,
}) {
  final travel = cardHeight - start - kPinnedStripHeight;
  if (travel <= 0) return 1;
  return ((plotAtTop - start) / travel).clamp(0.0, 1.0);
}

/// The strip background's opacity at condense progress [t], fully opaque
/// from [fadeEnd] on.
double condenseBackgroundOpacity(double t, {required double fadeEnd}) =>
    fadeEnd <= 0 ? 1 : (t / fadeEnd).clamp(0.0, 1.0);

/// How far the shape has morphed from the card's chart to the strip at
/// condense progress [t]: still until the background is opaque at
/// [fadeEnd], then eased.
double condenseMorphProgress(double t, {required double fadeEnd}) {
  final double u;
  if (fadeEnd >= 1) {
    u = t >= 1 ? 1 : 0;
  } else {
    u = ((t - fadeEnd) / (1 - fadeEnd)).clamp(0.0, 1.0);
  }
  return u * u * (3 - 2 * u);
}

/// How a depth curve maps onto the screen: a plot [rect] spanning
/// [minSeconds] to [maxSeconds] across and [minDepthMeters] (top) to
/// [maxDepthMeters] (bottom) down, the same mapping the profile chart uses.
class PlotMapping {
  const PlotMapping({
    required this.rect,
    required this.minSeconds,
    required this.maxSeconds,
    required this.minDepthMeters,
    required this.maxDepthMeters,
  });

  final Rect rect;
  final double minSeconds;
  final double maxSeconds;
  final double minDepthMeters;
  final double maxDepthMeters;

  Offset project(int seconds, double depthMeters) {
    final spanX = maxSeconds - minSeconds;
    final spanY = maxDepthMeters - minDepthMeters;
    return Offset(
      rect.left +
          (spanX <= 0 ? 0 : (seconds - minSeconds) / spanX) * rect.width,
      rect.top +
          (spanY <= 0 ? 0 : (depthMeters - minDepthMeters) / spanY) *
              rect.height,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PlotMapping &&
      other.rect == rect &&
      other.minSeconds == minSeconds &&
      other.maxSeconds == maxSeconds &&
      other.minDepthMeters == minDepthMeters &&
      other.maxDepthMeters == maxDepthMeters;

  @override
  int get hashCode =>
      Object.hash(rect, minSeconds, maxSeconds, minDepthMeters, maxDepthMeters);

  PlotMapping shift(Offset offset) => PlotMapping(
    rect: rect.shift(offset),
    minSeconds: minSeconds,
    maxSeconds: maxSeconds,
    minDepthMeters: minDepthMeters,
    maxDepthMeters: maxDepthMeters,
  );

  /// This mapping, moved down just enough that its plot is not above the top
  /// of the page (y 0), so no part of a curve drawn through it is out of
  /// view there. Unchanged when it is already in view.
  PlotMapping keptInView() =>
      rect.top >= 0 ? this : shift(Offset(0, -rect.top));

  /// The mapping [t] of the way from [a] to [b]: every point of a curve
  /// drawn through it moves continuously from where [a] draws it to where
  /// [b] does.
  static PlotMapping lerp(PlotMapping a, PlotMapping b, double t) {
    double mix(double x, double y) => x + (y - x) * t;
    return PlotMapping(
      rect: Rect.lerp(a.rect, b.rect, t)!,
      minSeconds: mix(a.minSeconds, b.minSeconds),
      maxSeconds: mix(a.maxSeconds, b.maxSeconds),
      minDepthMeters: mix(a.minDepthMeters, b.minDepthMeters),
      maxDepthMeters: mix(a.maxDepthMeters, b.maxDepthMeters),
    );
  }
}
