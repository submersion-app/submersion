import 'package:submersion/core/buoyancy/trim/trim_body.dart';
import 'package:submersion/features/equipment/figure/domain/figure_piece_data.dart';

/// One piece of the trim figure's side-view artwork, generated from
/// `scripts/artwork/figure_side/<id>.svg` (issue #5028).
///
/// Pieces are authored in side space in the straight pose. The painter turns
/// each one with its [segment] about that segment's joint; limb pieces are
/// drawn on the near (left) side and again, shaded, for the far limbs.
class TrimPieceData {
  const TrimPieceData({
    required this.id,
    required this.segment,
    required this.layer,
    required this.paths,
  });

  final String id;
  final TrimSegment segment;

  /// Paint order, low first. The body is 0.
  final int layer;
  final List<FigurePathData> paths;
}
