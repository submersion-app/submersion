import 'package:flutter/material.dart';

import 'package:submersion/core/buoyancy/trim/trim_body.dart';
import 'package:submersion/core/buoyancy/trim/trim_moment.dart';
import 'package:submersion/core/buoyancy/trim/trim_spot.dart';
import 'package:submersion/features/dive_log/presentation/widgets/trim/trim_artwork.gen.dart';
import 'package:submersion/features/dive_log/presentation/widgets/trim/trim_chip_layout.dart';
import 'package:submersion/features/dive_log/presentation/widgets/trim/trim_figure_geometry.dart';
import 'package:submersion/features/dive_log/presentation/widgets/trim/trim_figure_paths.dart';
import 'package:submersion/features/dive_log/presentation/widgets/trim/trim_piece_data.dart';
import 'package:submersion/features/equipment/figure/domain/figure_palette.dart';

/// The colours a chip is drawn in.
class TrimChipStyle {
  const TrimChipStyle({
    required this.fill,
    required this.text,
    required this.textStyle,
  });

  final Color fill;
  final Color text;
  final TextStyle textStyle;
}

/// Paints the posed, tilted side-view diver and its chips (issue #5028).
///
/// The viewer sees the diver's left side. The far (right) arm and leg are
/// painted first, shaded and set back, with the gear they carry; then the
/// torso with its gear (gear on the right of the torso behind it), then the
/// near shin, foot and arm, so the arm lies over the suit. Within each part
/// pieces paint in layer order.
class TrimFigurePainter extends CustomPainter {
  TrimFigurePainter({
    required this.elements,
    required this.geometry,
    required this.palette,
    required this.chips,
    required this.chipTexts,
    required this.chipStyles,
    required this.leaderColor,
    this.selectedElementId,
    this.selectedColor,
  });

  final List<TrimElement> elements;
  final TrimFigureGeometry geometry;
  final FigurePalette palette;
  final List<TrimChipPlacement> chips;

  /// Each chip's text by element id.
  final Map<String, String> chipTexts;
  final Map<String, TrimChipStyle> chipStyles;
  final Color leaderColor;
  final String? selectedElementId;
  final Color? selectedColor;

  /// How far, in side units, the far limbs are set back.
  static const Offset farOffset = Offset(5, -4);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    geometry.enter(canvas);
    _paintFigure(canvas);
    canvas.restore();
    _paintChips(canvas);
  }

  void _paintFigure(Canvas canvas) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    void draw(TrimPieceData piece, int color, {bool shaded = false}) {
      final paths = TrimFigurePaths.of(piece.id);
      for (var i = 0; i < paths.length; i++) {
        final c = Color(palette.colorFor(piece.paths[i].role, color));
        paint.color = shaded ? Color.lerp(c, Colors.black, 0.28)! : c;
        canvas.drawPath(paths[i], paint);
      }
    }

    bool farSide(TrimElement e) =>
        e.spot.sided && e.lateral == TrimLateral.right;

    // The body piece of [segment] (unless [bare]), then every piece of
    // [segment] carried by an element [include] accepts, in layer order.
    List<(TrimPieceData, int)> group(
      TrimSegment segment,
      bool Function(TrimElement) include, {
      bool bare = false,
    }) {
      final out = <(TrimPieceData, int)>[
        if (!bare)
          if (trimArtwork[_bodyPiece(segment)] case final body?) (body, 0),
      ];
      for (final e in elements) {
        if (!include(e)) continue;
        for (final id in e.pieceIds) {
          final piece = trimArtwork[id];
          if (piece != null && piece.segment == segment) {
            out.add((piece, e.color));
          }
        }
      }
      return out..sort((a, b) => a.$1.layer.compareTo(b.$1.layer));
    }

    void pass(
      TrimSegment segment,
      bool Function(TrimElement) include, {
      bool far = false,
      bool bare = false,
    }) {
      canvas.save();
      if (far) canvas.translate(farOffset.dx, farOffset.dy);
      geometry.enterSegment(canvas, segment);
      for (final (piece, color) in group(segment, include, bare: bare)) {
        draw(piece, color, shaded: far);
      }
      canvas.restore();
    }

    // Far limbs, set back and shaded: centred gear (suits, fins) is on both
    // sides, sided gear only when it is on the right.
    for (final segment in const [
      TrimSegment.arm,
      TrimSegment.shin,
      TrimSegment.foot,
    ]) {
      pass(segment, (e) => !e.spot.sided || farSide(e), far: true);
    }
    // Torso gear on the right, behind the body; then the torso and the rest.
    pass(TrimSegment.torso, farSide, far: true, bare: true);
    pass(TrimSegment.torso, (e) => !farSide(e));
    for (final segment in const [
      TrimSegment.shin,
      TrimSegment.foot,
      TrimSegment.arm,
    ]) {
      pass(segment, (e) => !farSide(e));
    }
  }

  static String _bodyPiece(TrimSegment segment) => switch (segment) {
    TrimSegment.torso => 'body_side_torso',
    TrimSegment.arm || TrimSegment.farArm => 'body_side_arm',
    TrimSegment.shin || TrimSegment.farShin => 'body_side_shin',
    TrimSegment.foot || TrimSegment.farFoot => 'body_side_foot',
  };

  void _paintChips(Canvas canvas) {
    final leader = Paint()
      ..color = leaderColor
      ..strokeWidth = 1
      ..isAntiAlias = true;
    for (final chip in chips) {
      final r = chip.rect;
      final end = Offset(
        chip.anchor.dx.clamp(r.left + 4, r.right - 4),
        chip.anchor.dy < r.top ? r.top : r.bottom,
      );
      canvas.drawLine(chip.anchor, end, leader);
      canvas.drawCircle(chip.anchor, 2.5, leader);
    }
    for (final chip in chips) {
      final style = chipStyles[chip.elementId];
      final text = chipTexts[chip.elementId];
      if (style == null || text == null) continue;
      final rrect = RRect.fromRectAndRadius(
        chip.rect,
        const Radius.circular(6),
      );
      canvas.drawRRect(rrect, Paint()..color = style.fill);
      if (chip.elementId == selectedElementId && selectedColor != null) {
        canvas.drawRRect(
          rrect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = selectedColor!,
        );
      }
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: style.textStyle.copyWith(color: style.text),
        ),
        maxLines: 1,
        ellipsis: '...',
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: chip.rect.width - 12);
      tp.paint(
        canvas,
        Offset(chip.rect.left + 6, chip.rect.center.dy - tp.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(TrimFigurePainter old) =>
      !identical(old.elements, elements) ||
      old.geometry.pose != geometry.pose ||
      old.geometry.scale != geometry.scale ||
      old.palette != palette ||
      !identical(old.chips, chips) ||
      old.selectedElementId != selectedElementId;
}
