import 'dart:ui';

/// Height of the pinned profile strip: a 40 px curve over a 16 px values row.
const double kPinnedStripHeight = 56;

/// How far the profile card has condensed into the strip, from 0 to 1.
///
/// [card] is the card's rect relative to the top of the scroll viewport. The
/// condense runs over the card's whole scroll-out: it starts the moment the
/// card's top passes the viewport's top and completes as its bottom reaches
/// the strip's, so scrolling slowly plays it slowly and scrolling back
/// reverses it.
double condenseProgress({required Rect card}) {
  if (card.top >= 0) return 0;
  final travel = card.height - kPinnedStripHeight;
  if (travel <= 0) return 1;
  return (-card.top / travel).clamp(0.0, 1.0);
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
