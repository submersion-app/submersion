import 'dart:ui';

/// Height of the pinned profile strip: a 40 px curve over a 16 px values row.
const double kPinnedStripHeight = 56;

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

/// How far the pinned card has squashed, from 0 to [range]: the distance
/// [card] (relative to the viewport's top) has scrolled past the top. The
/// squash starts the moment the card's top passes the viewport's; the
/// chart's plot takes all of it, its axes, grid and lines intact.
double squashDepth({required Rect card, double range = kSquashRange}) =>
    (-card.top).clamp(0.0, range);

/// How far the squashed card has slid up since the squash finished: after
/// it, the card leaves the top as it naturally would, header first, until
/// its chart's plot reaches the top.
double slideDepth({required Rect card, double range = kSquashRange}) =>
    (-card.top - range).clamp(0.0, double.infinity);

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

/// Where the condensing strip is drawn at progress [t]: always all of [card]
/// still on screen (top to its bottom edge), so the real card never shows
/// around it, widening from the card's margins to the full [width]. As the
/// card scrolls up the box shrinks with it, down to the strip.
Rect condenseRect({
  required Rect card,
  required double width,
  required double t,
}) {
  double mix(double a, double b) => a + (b - a) * t;
  return Rect.fromLTRB(
    mix(card.left, 0),
    card.top > 0 ? card.top : 0,
    mix(card.right, width),
    card.bottom > kPinnedStripHeight ? card.bottom : kPinnedStripHeight,
  );
}

/// The share of the condense spent fading the strip's background in over the
/// card while its depth line still sits exactly on the chart's, before the
/// shape moves at all. The chart's own line is hidden before the two could
/// part, so only one depth line is ever seen.
const double kCondenseFadePortion = 0.2;

/// The strip background's opacity at condense progress [t].
double condenseBackgroundOpacity(double t) =>
    (t / kCondenseFadePortion).clamp(0.0, 1.0);

/// How far the shape has morphed from the card's chart to the strip at
/// condense progress [t]: still until the background is opaque, then eased.
double condenseMorphProgress(double t) {
  final u = ((t - kCondenseFadePortion) / (1 - kCondenseFadePortion)).clamp(
    0.0,
    1.0,
  );
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
