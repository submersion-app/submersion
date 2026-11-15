import 'dart:math' as math;
import 'dart:ui';

import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_geometry.dart';

/// How much of a card must show below the pinned strip for it to count as
/// in view: enough to read.
const double kCardInViewMinPx = 96;

/// The cards of [cardsInContent] (each card's rect in scroll-content
/// coordinates) that are in view with the page scrolled to [pixels] in a
/// viewport [viewportHeight] tall (issue #4562).
///
/// A card is in view when at least [kCardInViewMinPx] of it, or all of it
/// when it is shorter, lies between a fixed edge [kPinnedStripGrownHeight]
/// below the top and the viewport's bottom. The edge is the grown strip's
/// bottom whatever the strip's height now, so the strip growing for a card
/// cannot push that card back out of view.
Set<DiveDetailSectionId> cardsInView({
  required Map<DiveDetailSectionId, Rect> cardsInContent,
  required double pixels,
  required double viewportHeight,
}) => {
  for (final MapEntry(key: id, value: card) in cardsInContent.entries)
    if (_shows(card.shift(Offset(0, -pixels)), viewportHeight)) id,
};

bool _shows(Rect card, double viewportHeight) {
  final span =
      math.min(card.bottom, viewportHeight) -
      math.max(card.top, kPinnedStripGrownHeight);
  return span >= math.min(kCardInViewMinPx, card.height);
}
