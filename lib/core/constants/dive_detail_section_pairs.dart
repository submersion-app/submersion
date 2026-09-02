import 'package:submersion/core/constants/dive_detail_sections.dart';

/// Two dive-detail sections whose cards render side by side when the detail
/// pane is wide enough.
///
/// [left] and [right] fix the on-screen arrangement independently of where
/// each section sits in the diver's configured order, so a saved order that
/// predates the pair still lays out the intended way.
class DiveDetailSectionPair {
  const DiveDetailSectionPair(this.left, this.right);

  /// The section shown in the left column (top card when stacked).
  final DiveDetailSectionId left;

  /// The section shown in the right column (bottom card when stacked).
  final DiveDetailSectionId right;

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
  DiveDetailSectionPair(
    DiveDetailSectionId.details,
    DiveDetailSectionId.environment,
  ),
  DiveDetailSectionPair(
    DiveDetailSectionId.surfaceGps,
    DiveDetailSectionId.tide,
  ),
  DiveDetailSectionPair(DiveDetailSectionId.tanks, DiveDetailSectionId.weights),
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
