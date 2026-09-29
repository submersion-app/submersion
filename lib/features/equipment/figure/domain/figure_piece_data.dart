import 'package:submersion/features/equipment/figure/domain/figure_role.dart';
import 'package:submersion/features/equipment/figure/domain/figure_view.dart';

/// One filled path of a piece: SVG path data in figure space plus its role.
class FigurePathData {
  const FigurePathData({required this.role, required this.d});

  final FigureRole role;
  final String d;
}

/// One piece of artwork, generated from `tool/figure/<id>.svg`.
///
/// Pieces are authored in absolute figure space. A piece placed in a
/// mirrored zone is flipped about the figure's centre line by the painter.
class FigurePieceData {
  const FigurePieceData({
    required this.id,
    required this.view,
    required this.layer,
    required this.paths,
  });

  final String id;
  final FigureView view;

  /// Paint order within a view, low first. The body is 0.
  final int layer;
  final List<FigurePathData> paths;
}
