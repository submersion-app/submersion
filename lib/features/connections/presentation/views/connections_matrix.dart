import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/features/connections/presentation/canvas/connection_kind_colors.dart';
import 'package:submersion/features/connections/presentation/views/matrix_model.dart';
import 'package:submersion/features/connections/presentation/views/matrix_painter.dart';
import 'package:submersion/features/connections/presentation/views/table_parts.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Shared dives between every pair on the map as a grid. Drag or scroll to
/// move; tap a cell to select the pair, a header to select the entity.
class ConnectionsMatrix extends StatefulWidget {
  const ConnectionsMatrix({
    super.key,
    required this.graph,
    required this.colors,
    required this.selection,
    required this.onSelect,
  });

  final ConnectionGraph graph;
  final ConnectionKindColors colors;
  final GraphSelection? selection;
  final ValueChanged<GraphSelection?> onSelect;

  @override
  State<ConnectionsMatrix> createState() => _ConnectionsMatrixState();
}

class _ConnectionsMatrixState extends State<ConnectionsMatrix> {
  Offset _scroll = Offset.zero;
  ConnectionGraph? _modelFor;
  late MatrixModel _model;

  final _text = MatrixTextCache();
  TextStyle? _textStyle;
  TextDirection? _textDirection;

  MatrixModel get _current {
    if (!identical(_modelFor, widget.graph)) {
      _modelFor = widget.graph;
      _model = MatrixModel.of(widget.graph);
      _text.clear();
    }
    return _model;
  }

  @override
  void dispose() {
    _text.clear();
    super.dispose();
  }

  Offset _clamped(Offset o, Size size, MatrixModel m) {
    final maxX = math.max(
      0.0,
      m.columns.length * MatrixGeometry.cell -
          (size.width - MatrixGeometry.rowHeader),
    );
    final maxY = math.max(
      0.0,
      m.rows.length * MatrixGeometry.cell -
          (size.height - MatrixGeometry.columnHeader) +
          kTableEndPadding,
    );
    return Offset(o.dx.clamp(0.0, maxX), o.dy.clamp(0.0, maxY));
  }

  void _tap(Offset p, MatrixModel m) {
    final hit = MatrixGeometry.hitAt(
      p,
      scroll: _scroll,
      rows: m.rows.length,
      columns: m.columns.length,
    );
    if (hit == null) return;
    final (:row, :column) = hit;
    if (row != null && column != null) {
      final e = m.edgeAt(row, column);
      if (e != null) widget.onSelect(EdgeSelection(e.source, e.target));
    } else if (row != null) {
      widget.onSelect(NodeSelection(m.rows[row].ref));
    } else if (column != null) {
      widget.onSelect(NodeSelection(m.columns[column].ref));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = _current;
    final textStyle = theme.textTheme.labelSmall!.copyWith(
      color: theme.colorScheme.onSurface,
    );
    final textDirection = Directionality.of(context);
    // Cached text is laid out in one style and one direction.
    if (textStyle != _textStyle || textDirection != _textDirection) {
      _text.clear();
      _textStyle = textStyle;
      _textDirection = textDirection;
    }
    final selection = widget.selection;
    final ConnectionEdge? selectedEdge = switch (selection) {
      EdgeSelection(:final a, :final b) =>
        widget.graph.edges
            .where((e) => e.touches(a) && e.touches(b))
            .firstOrNull,
      _ => null,
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        // A resize or a smaller map can leave the old scroll past the end.
        _scroll = _clamped(_scroll, size, m);
        return Semantics(
          container: true,
          label: context.l10n.connections_matrix_semantics(
            m.rows.length,
            m.columns.length,
            widget.graph.edges.length,
          ),
          child: Listener(
            onPointerSignal: (e) {
              if (e is PointerScrollEvent) {
                setState(
                  () => _scroll = _clamped(_scroll + e.scrollDelta, size, m),
                );
              }
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (d) => setState(
                () => _scroll = _clamped(_scroll - d.delta, size, m),
              ),
              onTapUp: (d) => _tap(d.localPosition, m),
              child: CustomPaint(
                key: const ValueKey('connections-matrix-paint'),
                size: size,
                painter: MatrixPainter(
                  model: m,
                  scroll: _scroll,
                  colors: widget.colors,
                  textStyle: textStyle,
                  text: _text,
                  fill: theme.colorScheme.primary,
                  onFill: theme.colorScheme.onPrimary,
                  grid: theme.colorScheme.outlineVariant,
                  tint: theme.colorScheme.secondaryContainer,
                  headerBackground: theme.colorScheme.surface,
                  textDirection: textDirection,
                  selectedNode: switch (selection) {
                    NodeSelection(:final ref) => ref,
                    _ => null,
                  },
                  selectedEdge: selectedEdge,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
