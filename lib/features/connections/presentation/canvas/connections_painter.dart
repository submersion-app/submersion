import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/layout_frame.dart';
import 'package:submersion/features/connections/presentation/canvas/connection_kind_colors.dart';
import 'package:submersion/features/connections/presentation/canvas/connection_kind_icons.dart';
import 'package:submersion/features/connections/presentation/canvas/graph_viewport.dart';
import 'package:submersion/features/connections/presentation/canvas/label_collision.dart';
import 'package:submersion/features/connections/presentation/canvas/node_metrics.dart';

/// Draws edges, nodes and labels for one frame. Pure function of its inputs;
/// the canvas widget owns gesture state, decoded photos and the text caches.
class ConnectionsPainter extends CustomPainter {
  ConnectionsPainter({
    required this.graph,
    required this.frame,
    required this.viewport,
    required this.colors,
    required this.labelStyle,
    this.selection,
    this.hovered,
    this.photos = const {},
    this.labelZoomThreshold = 0.6,
    this.maxLabelsAtLowZoom = 12,
    this.haloColor,
    Map<NodeRef, TextPainter>? labelCache,
    Map<NodeRef, TextPainter>? dimLabelCache,
    Map<(NodeRef, int), TextPainter>? initialsCache,
  }) : labelCache = labelCache ?? {},
       dimLabelCache = dimLabelCache ?? {},
       initialsCache = initialsCache ?? {};

  final ConnectionGraph graph;
  final LayoutFrame frame;
  final GraphViewport viewport;
  final ConnectionKindColors colors;
  final TextStyle labelStyle;
  final GraphSelection? selection;
  final NodeRef? hovered;

  /// Decoded buddy photos, keyed by node.
  final Map<NodeRef, ui.Image> photos;
  final double labelZoomThreshold;
  final int maxLabelsAtLowZoom;

  /// Painted behind each visible label so it reads over edges; none when
  /// null.
  final Color? haloColor;

  /// Laid-out text, owned by the canvas state so a frame never re-runs
  /// paragraph layout for every node (measured at about 7 ms per frame for
  /// 160 nodes without the cache). The canvas clears these when the graph or
  /// the label style changes.
  final Map<NodeRef, TextPainter> labelCache;
  final Map<NodeRef, TextPainter> dimLabelCache;
  final Map<(NodeRef, int), TextPainter> initialsCache;

  /// The nodes lit up by [selection]: a node's far ends, or both ends of an
  /// edge. Empty without a selection.
  static Set<NodeRef> neighboursOf(
    ConnectionGraph graph,
    GraphSelection? selection,
  ) {
    switch (selection) {
      case null:
        return const {};
      case NodeSelection(:final ref):
        return {for (final e in graph.edgesOf(ref)) e.otherEnd(ref)!};
      case EdgeSelection(:final a, :final b):
        return {a, b};
    }
  }

  double radiusOf(ConnectionNode n) =>
      NodeMetrics.radiusFor(n.diveCount, graph.maxDiveCount) *
      viewport.scale.clamp(0.5, 1.5);

  TextPainter _label(
    ConnectionNode n, {
    required bool dimmed,
    required Color ink,
  }) {
    final cache = dimmed ? dimLabelCache : labelCache;
    return cache.putIfAbsent(
      n.ref,
      () => TextPainter(
        text: TextSpan(
          text: n.label,
          style: dimmed
              ? labelStyle.copyWith(color: ink.withValues(alpha: 0.4))
              : labelStyle,
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: 140),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final lit = neighboursOf(graph, selection);
    final selectedNode = switch (selection) {
      NodeSelection(:final ref) => ref,
      _ => null,
    };
    final dim = selection != null;
    final ink = labelStyle.color ?? Colors.black;

    for (final e in graph.edges) {
      final a = frame.positions[e.source];
      final b = frame.positions[e.target];
      if (a == null || b == null) continue;
      final onSelection = switch (selection) {
        NodeSelection(:final ref) => e.touches(ref),
        EdgeSelection(:final a, :final b) => e.touches(a) && e.touches(b),
        null => false,
      };
      final alpha =
          NodeMetrics.edgeOpacityFor(e.weight, graph.maxWeight) *
          (dim && !onSelection ? 0.25 : 1);
      final paint = Paint()
        ..color = ink.withValues(alpha: alpha)
        ..strokeWidth =
            NodeMetrics.edgeWidthFor(e.weight, graph.maxWeight) *
            (onSelection ? 1.4 : 1)
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(viewport.toScreen(a), viewport.toScreen(b), paint);
    }

    final nodesByDives = [...graph.nodes]
      ..sort((x, y) => y.diveCount.compareTo(x.diveCount));
    final labelCandidates = <({NodeRef ref, Rect rect})>[];
    final nodesByRef = <NodeRef, ConnectionNode>{};

    final discs = <Rect>[];
    for (final n in nodesByDives) {
      final p = frame.positions[n.ref];
      if (p == null) continue;
      nodesByRef[n.ref] = n;
      final centre = viewport.toScreen(p);
      final r = radiusOf(n);
      final isSelected = n.ref == selectedNode;
      final isLit = isSelected || lit.contains(n.ref) || n.ref == hovered;
      final fill = colors
          .colorFor(n.ref.kind)
          .withValues(alpha: dim && !isLit ? 0.35 : 1);
      canvas.drawCircle(centre, r, Paint()..color = fill);
      discs.add(Rect.fromCircle(center: centre, radius: r));
      final photo = photos[n.ref];
      final glyph = NodeMetrics.glyphFor(
        kind: n.ref.kind,
        hasPhoto: photo != null,
        radius: r,
      );
      switch (glyph) {
        case NodeGlyph.photo:
          canvas.save();
          canvas.clipPath(
            Path()..addOval(Rect.fromCircle(center: centre, radius: r - 1.5)),
          );
          paintImage(
            canvas: canvas,
            rect: Rect.fromCircle(center: centre, radius: r),
            image: photo!,
            fit: BoxFit.cover,
            opacity: dim && !isLit ? 0.35 : 1,
          );
          canvas.restore();
        case NodeGlyph.icon:
          final size = (r * 1.1).round();
          final icon = connectionKindIcon(n.ref.kind);
          final tp = initialsCache.putIfAbsent(
            (n.ref, -size),
            () => TextPainter(
              text: TextSpan(
                text: String.fromCharCode(icon.codePoint),
                style: TextStyle(
                  fontFamily: icon.fontFamily,
                  package: icon.fontPackage,
                  fontSize: size.toDouble(),
                  color: Colors.white,
                ),
              ),
              textDirection: TextDirection.ltr,
            )..layout(),
          );
          tp.paint(canvas, centre - Offset(tp.width / 2, tp.height / 2));
        case NodeGlyph.initials:
          final fontSize = (r * 0.8).round();
          final tp = initialsCache.putIfAbsent(
            (n.ref, fontSize),
            () => TextPainter(
              text: TextSpan(
                text: NodeMetrics.initialsFor(n.label),
                style: labelStyle.copyWith(
                  color: Colors.white,
                  fontSize: fontSize.toDouble(),
                  fontWeight: FontWeight.w600,
                ),
              ),
              textDirection: TextDirection.ltr,
            )..layout(),
          );
          tp.paint(canvas, centre - Offset(tp.width / 2, tp.height / 2));
        case NodeGlyph.none:
          break;
      }
      if (isSelected || isLit) {
        canvas.drawCircle(
          centre,
          r + 2,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = isSelected ? 3 : 1.5
            ..color = ink,
        );
      }
      final tp = _label(n, dimmed: false, ink: ink);
      labelCandidates.add((
        ref: n.ref,
        rect: Rect.fromLTWH(
          centre.dx - tp.width / 2,
          centre.dy + r + 2,
          tp.width,
          tp.height,
        ),
      ));
    }

    final allowed = viewport.scale < labelZoomThreshold
        ? labelCandidates.take(maxLabelsAtLowZoom).toList()
        : labelCandidates;
    final forced = {?selectedNode, ...lit, ?hovered};
    final ranked = [
      ...allowed.where((c) => forced.contains(c.ref)),
      ...allowed.where((c) => !forced.contains(c.ref)),
    ];
    final visible = LabelCollision.visible(ranked, obstacles: discs);
    for (final c in ranked) {
      if (!visible.contains(c.ref)) continue;
      final dimmed = dim && !forced.contains(c.ref);
      final tp = _label(nodesByRef[c.ref]!, dimmed: dimmed, ink: ink);
      final halo = haloColor;
      if (halo != null) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(c.rect.inflate(2), const Radius.circular(4)),
          Paint()..color = halo.withValues(alpha: 0.85),
        );
      }
      tp.paint(canvas, c.rect.topLeft);
    }
  }

  @override
  bool shouldRepaint(ConnectionsPainter old) =>
      old.frame != frame ||
      old.graph != graph ||
      old.viewport.scale != viewport.scale ||
      old.viewport.offset != viewport.offset ||
      old.selection != selection ||
      old.hovered != hovered ||
      old.photos.length != photos.length ||
      old.labelStyle != labelStyle ||
      old.haloColor != haloColor;
}
