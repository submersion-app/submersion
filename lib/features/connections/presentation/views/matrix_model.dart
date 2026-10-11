import 'package:flutter/painting.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/node_order.dart';

/// The matrix's axes and cells. A map of exactly two kinds linked only to
/// each other puts one kind on the rows (the bigger one) and the other on
/// the columns; any other map has every node on both axes.
class MatrixModel {
  MatrixModel._(
    this.rows,
    this.columns,
    this._cells,
    this.maxWeight,
    this.symmetric,
  );

  factory MatrixModel.of(ConnectionGraph graph) {
    final cells = <(NodeRef, NodeRef), ConnectionEdge>{
      for (final e in graph.edges) ...{
        (e.source, e.target): e,
        (e.target, e.source): e,
      },
    };
    final kinds = {for (final n in graph.nodes) n.ref.kind}.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    final crossOnly = graph.edges.every((e) => e.source.kind != e.target.kind);
    if (kinds.length == 2 && crossOnly) {
      List<ConnectionNode> of(ConnectionKind k) => [
        for (final n in graph.nodes)
          if (n.ref.kind == k) n,
      ]..sort(compareDivesLabel);
      final a = of(kinds[0]);
      final b = of(kinds[1]);
      final aOnRows = a.length >= b.length;
      return MatrixModel._(
        aOnRows ? a : b,
        aOnRows ? b : a,
        cells,
        graph.maxWeight,
        false,
      );
    }
    final all = [...graph.nodes]..sort(compareKindDivesLabel);
    return MatrixModel._(all, all, cells, graph.maxWeight, true);
  }

  final List<ConnectionNode> rows;
  final List<ConnectionNode> columns;
  final Map<(NodeRef, NodeRef), ConnectionEdge> _cells;
  final int maxWeight;
  final bool symmetric;

  ConnectionEdge? edgeAt(int row, int column) {
    final a = rows[row].ref;
    final b = columns[column].ref;
    return a == b ? null : _cells[(a, b)];
  }
}

/// Sizes and hit testing shared by the matrix widget and its painter.
abstract final class MatrixGeometry {
  static const double cell = 36;
  static const double rowHeader = 140;
  static const double columnHeader = 120;

  /// What sits under [p]: a cell (both set), a row header (column null), a
  /// column header (row null), or null for the corner and anything past the
  /// last row or column.
  static ({int? row, int? column})? hitAt(
    Offset p, {
    required Offset scroll,
    required int rows,
    required int columns,
  }) {
    final inRowHeader = p.dx < rowHeader;
    final inColumnHeader = p.dy < columnHeader;
    if (inRowHeader && inColumnHeader) return null;
    final column = ((p.dx - rowHeader + scroll.dx) / cell).floor();
    final row = ((p.dy - columnHeader + scroll.dy) / cell).floor();
    final columnOk = column >= 0 && column < columns;
    final rowOk = row >= 0 && row < rows;
    if (inColumnHeader) return columnOk ? (row: null, column: column) : null;
    if (inRowHeader) return rowOk ? (row: row, column: null) : null;
    return rowOk && columnOk ? (row: row, column: column) : null;
  }
}
