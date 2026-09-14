import 'package:submersion/core/constants/site_detail_sections.dart';

/// Two Site Details cards that render side by side when the pane is wide
/// enough.
///
/// [left] and [right] fix the on-screen arrangement independently of where
/// each card sits in the diver's order.
class SiteDetailSectionPair {
  const SiteDetailSectionPair(this.left, this.right, {this.minRowWidth = 700});

  /// The card in the left column (top card when stacked).
  final SiteDetailSectionId left;

  /// The card in the right column (bottom card when stacked).
  final SiteDetailSectionId right;

  /// At or above this available width the two cards sit side by side.
  final double minRowWidth;

  /// The other half of the pair, or null when [id] is not part of it.
  SiteDetailSectionId? partnerOf(SiteDetailSectionId id) {
    if (id == left) return right;
    if (id == right) return left;
    return null;
  }
}

/// Every Site Details card pair: four short cards that waste most of a wide
/// pane on their own. A card belongs to at most one pair.
const List<SiteDetailSectionPair> kSiteDetailSectionPairs = [
  SiteDetailSectionPair(
    SiteDetailSectionId.difficulty,
    SiteDetailSectionId.rating,
  ),
  SiteDetailSectionPair(
    SiteDetailSectionId.hazards,
    SiteDetailSectionId.access,
  ),
];

/// The pair [id] belongs to, or null when the card never pairs.
SiteDetailSectionPair? siteDetailSectionPairFor(SiteDetailSectionId id) {
  for (final pair in kSiteDetailSectionPairs) {
    if (pair.partnerOf(id) != null) return pair;
  }
  return null;
}
