import 'package:flutter/rendering.dart';
import 'package:submersion/features/equipment/figure/artwork/figure_artwork.gen.dart';
import 'package:submersion/features/equipment/figure/domain/figure_model.dart';
import 'package:submersion/features/equipment/figure/domain/figure_palette.dart';
import 'package:submersion/features/equipment/figure/domain/figure_piece_data.dart';
import 'package:submersion/features/equipment/figure/domain/figure_space.dart';
import 'package:submersion/features/equipment/figure/domain/figure_view.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_layout.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_paths.dart';

/// Draws the front and back figures for a [FigureModel].
///
/// Each view paints the mannequin, then every placed piece of that view in
/// layer order (ties broken by item number), each path filled with its
/// role's colour. A piece on a mirrored zone is flipped about the figure's
/// centre line. Discs are not painted here; the widget positions them.
class DiverFigurePainter extends CustomPainter {
  DiverFigurePainter({
    required this.model,
    required this.palette,
    this.layout,
    this.only,
  });

  final FigureModel model;
  final FigurePalette palette;

  /// The layout to draw in; defaults to the pair, or the single figure when
  /// [only] is set. The widget passes its own so labels and art agree.
  final FigureLayout? layout;

  /// Draw just this view (the phone layout).
  final FigureView? only;

  @override
  void paint(Canvas canvas, Size size) {
    final l =
        layout ??
        (only == null
            ? FigureLayout.forSize(size)
            : FigureLayout.forSingle(size));
    for (final view in FigureView.values) {
      if (only != null && view != only) continue;
      final rect = l.rectFor(view);
      canvas.save();
      canvas.translate(rect.left, rect.top);
      canvas.scale(l.scale);
      _paintView(canvas, view);
      canvas.restore();
    }
  }

  void _paintView(Canvas canvas, FigureView view) {
    final bodyId = view == FigureView.front ? 'body_front' : 'body_back';
    final entries =
        <_Entry>[
          _Entry(
            piece: figureArtwork[bodyId]!,
            itemColor: 0,
            mirrored: false,
            order: 0,
          ),
          for (final item in model.placed)
            for (final id in item.pieceIds)
              if (figureArtwork[id] case final piece? when piece.view == view)
                _Entry(
                  piece: piece,
                  itemColor: item.color,
                  mirrored: item.zone!.mirrored,
                  order: item.number,
                ),
        ]..sort((a, b) {
          final byLayer = a.piece.layer.compareTo(b.piece.layer);
          return byLayer != 0 ? byLayer : a.order.compareTo(b.order);
        });

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    for (final entry in entries) {
      canvas.save();
      if (entry.mirrored) {
        canvas.translate(kFigureWidth, 0);
        canvas.scale(-1, 1);
      }
      final paths = FigurePaths.of(entry.piece.id);
      for (var i = 0; i < paths.length; i++) {
        final role = entry.piece.paths[i].role;
        paint.color = Color(palette.colorFor(role, entry.itemColor));
        canvas.drawPath(paths[i], paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(DiverFigurePainter oldDelegate) =>
      !identical(oldDelegate.model, model) ||
      !identical(oldDelegate.palette, palette) ||
      oldDelegate.only != only ||
      oldDelegate.layout?.front != layout?.front;
}

class _Entry {
  const _Entry({
    required this.piece,
    required this.itemColor,
    required this.mirrored,
    required this.order,
  });

  final FigurePieceData piece;
  final int itemColor;
  final bool mirrored;
  final int order;
}
