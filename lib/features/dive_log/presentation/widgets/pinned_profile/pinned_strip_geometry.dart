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
