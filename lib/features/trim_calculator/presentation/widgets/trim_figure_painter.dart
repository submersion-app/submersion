import 'package:flutter/material.dart';

import 'package:submersion/core/buoyancy/trim/trim_body.dart';
import 'package:submersion/core/buoyancy/trim/trim_moment.dart';
import 'package:submersion/core/buoyancy/trim/trim_spot.dart';
import 'package:submersion/features/trim_calculator/presentation/widgets/trim_artwork.gen.dart';
import 'package:submersion/features/trim_calculator/presentation/widgets/trim_chip_layout.dart';
import 'package:submersion/features/trim_calculator/presentation/widgets/trim_figure_geometry.dart';
import 'package:submersion/features/trim_calculator/presentation/widgets/trim_figure_paths.dart';
import 'package:submersion/features/trim_calculator/presentation/widgets/trim_piece_data.dart';
import 'package:submersion/features/trim_calculator/presentation/widgets/trim_space.dart';
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

/// Whether [e] is drawn on the far (right) limbs: gear on the right of a
/// sided spot, and gear on both sides (gloves, both ankle weights, suits,
/// fins). The viewer sees the diver's left side.
bool trimOnFarSide(TrimElement e) =>
    !e.spot.sided || e.lateral != TrimLateral.left;

/// Whether [e] is drawn on the near (left) side.
bool trimOnNearSide(TrimElement e) =>
    !e.spot.sided || e.lateral != TrimLateral.right;

/// How far [e]'s pieces are drawn from where its spot puts them, in side
/// units: a tank slid along its band moves along the body.
Offset trimShiftOffset(TrimElement e, TrimBody body) => e.shiftM == 0
    ? Offset.zero
    : Offset(e.shiftM / body.heightM * kTrimUnitsPerHeight, 0);

/// How far each element drawn with others at the same place is set apart,
/// in side units, so three stages on one clip read as three. The first at
/// a place stays put.
Map<String, Offset> trimStackOffsets(List<TrimElement> elements) {
  final seen = <(TrimSpot, TrimLateral, String), int>{};
  final out = <String, Offset>{};
  for (final e in elements) {
    if (e.pieceIds.isEmpty) continue;
    final key = (e.spot, e.lateral, e.pieceIds.first);
    final k = seen[key] ?? 0;
    seen[key] = k + 1;
    out[e.id] = Offset(6.0 * k, 12.0 * k);
  }
  return out;
}

/// Paints the posed, tilted side-view diver and its chips (issue #5028).
///
/// The far (right) arm and leg are painted first, shaded and set back, with
/// the gear they carry; then the torso with its gear (gear on the right of
/// the torso behind it), then the near shin, foot and arm, so the arm lies
/// over the suit. Within each part pieces paint in layer order.
class TrimFigurePainter extends CustomPainter {
  TrimFigurePainter({
    required this.elements,
    required this.geometry,
    required this.palette,
    required this.chips,
    required this.chipTexts,
    required this.chipStyles,
    required this.leaderColor,
    this.textDirection = TextDirection.ltr,
    this.selectedElementId,
    this.selectedColor,
    this.dragTarget,
    this.dragGhost,
  }) : _stack = trimStackOffsets(elements);

  final List<TrimElement> elements;
  final TrimFigureGeometry geometry;
  final FigurePalette palette;
  final List<TrimChipPlacement> chips;

  /// Each chip's text by element id.
  final Map<String, String> chipTexts;
  final Map<String, TrimChipStyle> chipStyles;
  final Color leaderColor;
  final TextDirection textDirection;
  final String? selectedElementId;
  final Color? selectedColor;

  /// While a chip is dragged: the anchor of the spot it would land on, and
  /// the chip's outline under the finger.
  final Offset? dragTarget;
  final Rect? dragGhost;
  final Map<String, Offset> _stack;

  /// How far, in side units, the far limbs are set back.
  static const Offset farOffset = Offset(5, -4);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    geometry.enter(canvas);
    _paintFigure(canvas);
    canvas.restore();
    _paintChips(canvas);
    _paintDrag(canvas);
  }

  void _paintFigure(Canvas canvas) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    void draw(
      TrimPieceData piece,
      int color,
      Offset offset, {
      bool shaded = false,
    }) {
      final paths = TrimFigurePaths.of(piece.id);
      if (offset != Offset.zero) {
        canvas.save();
        canvas.translate(offset.dx, offset.dy);
      }
      for (var i = 0; i < paths.length; i++) {
        final c = Color(palette.colorFor(piece.paths[i].role, color));
        paint.color = shaded ? Color.lerp(c, Colors.black, 0.28)! : c;
        canvas.drawPath(paths[i], paint);
      }
      if (offset != Offset.zero) canvas.restore();
    }

    // The body piece of [segment] (unless [bare]), then every piece of
    // [segment] carried by an element [include] accepts, in layer order.
    List<(TrimPieceData, int, Offset)> group(
      TrimSegment segment,
      bool Function(TrimElement) include, {
      bool bare = false,
    }) {
      final out = <(TrimPieceData, int, Offset)>[
        if (!bare)
          if (trimArtwork[_bodyPiece(segment)] case final body?)
            (body, 0, Offset.zero),
      ];
      for (final e in elements) {
        if (!include(e)) continue;
        for (final id in e.pieceIds) {
          final piece = trimArtwork[id];
          if (piece != null && piece.segment == segment) {
            out.add((
              piece,
              e.color,
              (_stack[e.id] ?? Offset.zero) + trimShiftOffset(e, geometry.body),
            ));
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
      for (final (piece, color, offset) in group(
        segment,
        include,
        bare: bare,
      )) {
        draw(piece, color, offset, shaded: far);
      }
      canvas.restore();
    }

    for (final segment in const [
      TrimSegment.arm,
      TrimSegment.shin,
      TrimSegment.foot,
    ]) {
      pass(segment, trimOnFarSide, far: true);
    }
    // Torso gear on the right, behind the body; then the torso and the rest.
    pass(
      TrimSegment.torso,
      (e) => e.spot.sided && e.lateral == TrimLateral.right,
      far: true,
      bare: true,
    );
    pass(TrimSegment.torso, trimOnNearSide);
    for (final segment in const [
      TrimSegment.shin,
      TrimSegment.foot,
      TrimSegment.arm,
    ]) {
      pass(segment, trimOnNearSide);
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
        textDirection: textDirection,
      )..layout(maxWidth: chip.rect.width - 12);
      tp.paint(
        canvas,
        Offset(chip.rect.left + 6, chip.rect.center.dy - tp.height / 2),
      );
      tp.dispose();
    }
  }

  void _paintDrag(Canvas canvas) {
    final color = selectedColor ?? leaderColor;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color
      ..isAntiAlias = true;
    if (dragTarget case final target?) {
      canvas.drawCircle(target, 8, stroke);
      canvas.drawCircle(target, 3, Paint()..color = color);
    }
    if (dragGhost case final ghost?) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(ghost, const Radius.circular(6)),
        stroke,
      );
      if (dragTarget case final target?) {
        canvas.drawLine(ghost.center, target, stroke..strokeWidth = 1);
      }
    }
  }

  @override
  bool shouldRepaint(TrimFigurePainter old) =>
      !identical(old.elements, elements) ||
      old.geometry.pose != geometry.pose ||
      old.geometry.scale != geometry.scale ||
      old.palette != palette ||
      !identical(old.chips, chips) ||
      old.selectedElementId != selectedElementId ||
      old.dragTarget != dragTarget ||
      old.dragGhost != dragGhost ||
      old.textDirection != textDirection;
}
