import 'dart:ui';

/// Height of the pinned profile strip, all curve: its values float in a
/// tooltip below it while it is scrubbed (issue #4509).
const double kPinnedStripHeight = 44;

/// Height of the pinned strip while it draws a line layer of a card in view
/// (issue #4562): room for several lines on scales of their own.
const double kPinnedStripGrownHeight = 72;

/// The shortest the squashed chart's plot gets: the strip's own height, so
/// it is still a readable chart when the strip takes over from it, and the
/// two meet as the strip settles. Any taller and the strip, which never
/// rises above the plot, settled that much too tall and shrank after
/// (#4579).
const double kMinPlotHeight = kPinnedStripHeight;

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
/// in. The fade and then the morph ([kCondenseFadeEnd]) have to be over by
/// the end of it, so an early start gives them a long stretch of scroll to
/// spread over.
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
/// hand-over starts once the card has scrolled [start] past the top and
/// completes [end] px past it, as the card's plot reaches the top of the
/// page, so scrolling slowly plays it slowly and scrolling back reverses it.
///
/// It is over by then, not when the card's bottom reaches the strip: what
/// is left of the card below its plot (its axis and legend) slides up under
/// the settled strip, and the cards below it come into view with the strip
/// already scrubbable and showing their layers (issue #4579).
double condenseProgress({
  required Rect card,
  required double start,
  required double end,
}) {
  final past = -card.top - start;
  if (past <= 0) return 0;
  final travel = end - start;
  if (travel <= 0) return 1;
  return (past / travel).clamp(0.0, 1.0);
}

/// Where, as a share of the hand-over ([condenseProgress]), the strip's
/// background has fully faded in over the card's plot.
///
/// Until then the strip's depth line sits exactly on the chart's, so only
/// one line is seen; past it the strip, opaque, morphs to its own shape
/// while the chart's plot slides up beneath it. The fade follows the scroll
/// position, so the same point is where the chart starts coming back when
/// scrolling up.
const double kCondenseFadeEnd = 0.5;

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

/// The mapping to hand the strip's painter as where its line starts
/// (`PinnedStripPainter.from`, in the strip's own coordinates) so that the
/// line is drawn [morph] of the way from [start] to [end], both on the page,
/// while the strip's [box] (on the page) is itself on its way.
///
/// The painter blends from what it is handed to its own curve area, [own]
/// (in the box), by [morph]. Handed [start] as it stands, moved into the
/// box, the line took the morph twice, once with the box and once inside
/// it, and lagged the box's edges: a blank border around it (#4579). This
/// is the mapping whose blend lands where the line belongs. Its time and
/// depth ranges are [start]'s, which the painter blends as before.
PlotMapping morphStartFor({
  required PlotMapping start,
  required Rect end,
  required Rect box,
  required Rect own,
  required double morph,
}) {
  final rest = 1 - morph;
  final wanted = Rect.lerp(start.rect, end, morph)!.shift(-box.topLeft);
  // Settled, nothing is left to blend from; the painter draws through its
  // own area then.
  if (rest <= 0) {
    return PlotMapping(
      rect: own,
      minSeconds: start.minSeconds,
      maxSeconds: start.maxSeconds,
      minDepthMeters: start.minDepthMeters,
      maxDepthMeters: start.maxDepthMeters,
    );
  }
  double undo(double target, double ownEdge) =>
      (target - morph * ownEdge) / rest;
  return PlotMapping(
    rect: Rect.fromLTRB(
      undo(wanted.left, own.left),
      undo(wanted.top, own.top),
      undo(wanted.right, own.right),
      undo(wanted.bottom, own.bottom),
    ),
    minSeconds: start.minSeconds,
    maxSeconds: start.maxSeconds,
    minDepthMeters: start.minDepthMeters,
    maxDepthMeters: start.maxDepthMeters,
  );
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
