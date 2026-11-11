import 'dart:ui';

/// Height of the pinned profile strip: a 40 px curve over a 16 px values row.
const double kPinnedStripHeight = 56;

/// How far, in logical pixels, the profile card's bottom edge travels while
/// the card condenses into the strip.
const double kCondenseWindow = 120;

/// How far the profile card has condensed into the strip, from 0 to 1.
///
/// [cardBottom] is the card's bottom edge relative to the top of the scroll
/// viewport. Progress starts once that edge is within [kCondenseWindow] of
/// the strip's bottom edge and completes as it reaches it, so scrolling
/// slowly plays the condense slowly and scrolling back reverses it.
double condenseProgress({required double cardBottom}) {
  final t =
      (kPinnedStripHeight + kCondenseWindow - cardBottom) / kCondenseWindow;
  return t.clamp(0.0, 1.0);
}

/// Where the condensing proxy is drawn at progress [t]: from the visible part
/// of [card] (its top clamped to the viewport's top) to the full-[width]
/// strip at the top.
Rect condenseRect({
  required Rect card,
  required double width,
  required double t,
}) {
  final visible = Rect.fromLTRB(
    card.left,
    card.top < 0 ? 0 : card.top,
    card.right,
    card.bottom,
  );
  final strip = Rect.fromLTWH(0, 0, width, kPinnedStripHeight);
  return Rect.lerp(visible, strip, t)!;
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
