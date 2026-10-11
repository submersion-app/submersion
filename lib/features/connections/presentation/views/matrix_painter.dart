import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/presentation/canvas/connection_kind_colors.dart';
import 'package:submersion/features/connections/presentation/views/matrix_model.dart';

/// Laid-out matrix text, kept across frames by the matrix widget so a
/// scroll never re-lays out the same header or count. The owner clears it
/// when the map, the text style or the text direction changes.
class MatrixTextCache {
  final Map<Object, TextPainter> painters = {};

  TextPainter get(Object key, TextPainter Function() build) =>
      painters.putIfAbsent(key, build);

  void clear() {
    for (final p in painters.values) {
      p.dispose();
    }
    painters.clear();
  }
}

/// Paints only the visible cells, with the row and column headers frozen at
/// the left and top.
class MatrixPainter extends CustomPainter {
  MatrixPainter({
    required this.model,
    required this.scroll,
    required this.colors,
    required this.textStyle,
    required this.fill,
    required this.onFill,
    required this.grid,
    required this.tint,
    required this.headerBackground,
    this.textDirection = TextDirection.ltr,
    this.selectedNode,
    this.selectedEdge,
    MatrixTextCache? text,
  }) : text = text ?? MatrixTextCache();

  final MatrixModel model;
  final Offset scroll;
  final ConnectionKindColors colors;
  final TextStyle textStyle;

  /// The strength shade; a cell's opacity grows with its shared dives.
  final Color fill;

  /// Count text on a cell shaded past halfway, where [textStyle]'s colour
  /// would lose contrast.
  final Color onFill;
  final Color grid;
  final Color tint;
  final Color headerBackground;

  /// The reading direction for header and count text.
  final TextDirection textDirection;
  final NodeRef? selectedNode;
  final ConnectionEdge? selectedEdge;

  /// Where laid-out header and count text lives between frames.
  final MatrixTextCache text;

  static const _cell = MatrixGeometry.cell;
  static const _rowHeader = MatrixGeometry.rowHeader;
  static const _columnHeader = MatrixGeometry.columnHeader;

  @override
  void paint(Canvas canvas, Size size) {
    if (model.rows.isEmpty || model.columns.isEmpty) return;
    final lastColIndex = model.columns.length - 1;
    final lastRowIndex = model.rows.length - 1;
    final firstCol = (scroll.dx / _cell).floor().clamp(0, lastColIndex);
    final lastCol = ((scroll.dx + size.width - _rowHeader) / _cell)
        .ceil()
        .clamp(0, lastColIndex);
    final firstRow = (scroll.dy / _cell).floor().clamp(0, lastRowIndex);
    final lastRow = ((scroll.dy + size.height - _columnHeader) / _cell)
        .ceil()
        .clamp(0, lastRowIndex);
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    canvas.save();
    canvas.clipRect(
      Rect.fromLTRB(_rowHeader, _columnHeader, size.width, size.height),
    );
    for (var r = firstRow; r <= lastRow; r++) {
      for (var c = firstCol; c <= lastCol; c++) {
        final rect = Rect.fromLTWH(
          _rowHeader + c * _cell - scroll.dx,
          _columnHeader + r * _cell - scroll.dy,
          _cell,
          _cell,
        );
        final rowRef = model.rows[r].ref;
        final colRef = model.columns[c].ref;
        if (selectedNode != null &&
            (rowRef == selectedNode || colRef == selectedNode)) {
          canvas.drawRect(rect, Paint()..color = tint);
        }
        final edge = model.edgeAt(r, c);
        if (edge != null) {
          final t = model.maxWeight <= 0 ? 1.0 : edge.weight / model.maxWeight;
          canvas.drawRect(
            rect.deflate(2),
            Paint()..color = fill.withValues(alpha: 0.15 + 0.75 * t),
          );
          final strong = t > 0.5;
          final tp = text.get(
            ('count', edge.weight, strong),
            () => TextPainter(
              text: TextSpan(
                text: '${edge.weight}',
                style: strong ? textStyle.copyWith(color: onFill) : textStyle,
              ),
              textDirection: textDirection,
            )..layout(),
          );
          tp.paint(canvas, rect.center - Offset(tp.width / 2, tp.height / 2));
          if (edge == selectedEdge) {
            canvas.drawRect(
              rect.deflate(1),
              Paint()
                ..color = textStyle.color ?? Colors.black
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2,
            );
          }
        }
        canvas.drawRect(rect, gridPaint);
      }
    }
    canvas.restore();

    // Row headers.
    final rowHeaders = Rect.fromLTRB(0, _columnHeader, _rowHeader, size.height);
    canvas.save();
    canvas.clipRect(rowHeaders);
    canvas.drawRect(rowHeaders, Paint()..color = headerBackground);
    for (var r = firstRow; r <= lastRow; r++) {
      final n = model.rows[r];
      final top = _columnHeader + r * _cell - scroll.dy;
      _headerLabel(
        canvas,
        n.ref,
        n.label,
        Offset(8, top + _cell / 2),
        _rowHeader - 24,
      );
    }
    canvas.restore();

    // Column headers, rotated to read bottom to top.
    final columnHeaders = Rect.fromLTRB(
      _rowHeader,
      0,
      size.width,
      _columnHeader,
    );
    canvas.save();
    canvas.clipRect(columnHeaders);
    canvas.drawRect(columnHeaders, Paint()..color = headerBackground);
    for (var c = firstCol; c <= lastCol; c++) {
      final n = model.columns[c];
      final cx = _rowHeader + c * _cell - scroll.dx + _cell / 2;
      canvas.save();
      canvas.translate(cx, _columnHeader - 8);
      canvas.rotate(-math.pi / 2);
      _headerLabel(canvas, n.ref, n.label, Offset.zero, _columnHeader - 28);
      canvas.restore();
    }
    canvas.restore();
  }

  /// A kind dot then the label, vertically centred on [at].
  void _headerLabel(
    Canvas canvas,
    NodeRef ref,
    String label,
    Offset at,
    double maxWidth,
  ) {
    canvas.drawCircle(
      at + const Offset(4, 0),
      4,
      Paint()..color = colors.colorFor(ref.kind),
    );
    final selected = ref == selectedNode;
    final tp = text.get(
      ('header', ref, selected, maxWidth),
      () => TextPainter(
        text: TextSpan(
          text: label,
          style: selected
              ? textStyle.copyWith(fontWeight: FontWeight.w700)
              : textStyle,
        ),
        textDirection: textDirection,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: maxWidth),
    );
    tp.paint(canvas, at + Offset(14, -tp.height / 2));
  }

  @override
  bool shouldRepaint(MatrixPainter old) =>
      old.model != model ||
      old.scroll != scroll ||
      old.selectedNode != selectedNode ||
      old.selectedEdge != selectedEdge ||
      old.textStyle != textStyle ||
      old.fill != fill ||
      old.onFill != onFill ||
      old.tint != tint ||
      old.grid != grid ||
      old.headerBackground != headerBackground ||
      old.textDirection != textDirection;
}
