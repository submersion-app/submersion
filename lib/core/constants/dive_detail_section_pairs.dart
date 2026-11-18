import 'package:submersion/core/constants/dive_detail_sections.dart';

/// Two dive-detail sections whose cards render side by side when the detail
/// pane is wide enough.
///
/// [left] and [right] fix the on-screen arrangement independently of where
/// each section sits in the diver's configured order, so a saved order that
/// predates the pair still lays out the intended way.
class DiveDetailSectionPair {
  const DiveDetailSectionPair(
    this.left,
    this.right, {
    this.minRowWidth = 700,
    this.stretch = false,
  });

  /// The section shown in the left column (top card when stacked).
  final DiveDetailSectionId left;

  /// The section shown in the right column (bottom card when stacked).
  final DiveDetailSectionId right;

  /// At or above this available width the two cards sit side by side.
  final double minRowWidth;

  /// Whether the row shares its height through an `IntrinsicHeight`.
  ///
  /// Every pair's cards end level in row mode (issue #4583). True only where
  /// a card holds `Expanded` children and so cannot first be laid out at its
  /// natural height: the deco column pads itself against the taller tissue
  /// card so the pair reads as one block. See `ResponsiveSectionPair.stretch`.
  final bool stretch;

  /// The other half of the pair, or null when [id] is not part of it.
  DiveDetailSectionId? partnerOf(DiveDetailSectionId id) {
    if (id == left) return right;
    if (id == right) return left;
    return null;
  }
}

/// Every dive-detail card pair, in left-then-right order.
///
/// A section belongs to at most one pair; [diveDetailSectionPairFor] relies on
/// that. The default section order in [DiveDetailSectionId] lists each pair's
/// halves adjacently and in this same order.
const List<DiveDetailSectionPair> kDiveDetailSectionPairs = [
  // The deco column and the tissue heat map were one card until the diver
  // could hide them separately; they pair back together at the 600px the
  // combined panel used, and stretch the way it did.
  DiveDetailSectionPair(
    DiveDetailSectionId.decoStatus,
    DiveDetailSectionId.tissueLoading,
    minRowWidth: 600,
    stretch: true,
  ),
  DiveDetailSectionPair(
    DiveDetailSectionId.tanks,
    DiveDetailSectionId.sacSegments,
  ),
  DiveDetailSectionPair(
    DiveDetailSectionId.details,
    DiveDetailSectionId.environment,
  ),
  DiveDetailSectionPair(
    DiveDetailSectionId.surfaceGps,
    DiveDetailSectionId.tide,
  ),
  DiveDetailSectionPair(
    DiveDetailSectionId.weights,
    DiveDetailSectionId.buoyancy,
  ),
  DiveDetailSectionPair(
    DiveDetailSectionId.buddies,
    DiveDetailSectionId.signatures,
  ),
];

/// The pair [id] belongs to, or null when the section never pairs.
DiveDetailSectionPair? diveDetailSectionPairFor(DiveDetailSectionId id) {
  for (final pair in kDiveDetailSectionPairs) {
    if (pair.partnerOf(id) != null) return pair;
  }
  return null;
}

/// Sections whose card never moves up into the space a pair leaves under its
/// shorter half: charts, maps, galleries and tables, which want the page's
/// full width (issue #4583). Any other card that comes straight after a pair
/// does, when it fits there at half width.
const Set<DiveDetailSectionId> kDiveDetailFullWidthSections = {
  DiveDetailSectionId.profile,
  DiveDetailSectionId.decoStatus,
  DiveDetailSectionId.tissueLoading,
  DiveDetailSectionId.sacSegments,
  DiveDetailSectionId.surfaceGps,
  DiveDetailSectionId.navTrack,
  DiveDetailSectionId.media,
  DiveDetailSectionId.documents,
  DiveDetailSectionId.diveLab,
  DiveDetailSectionId.dataSources,
};
