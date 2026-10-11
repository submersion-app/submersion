import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/presentation/views/matrix_model.dart';

NodeRef _b(String id) => NodeRef(ConnectionKind.buddy, id);
NodeRef _s(String id) => NodeRef(ConnectionKind.site, id);
ConnectionNode _n(NodeRef r, int dives) =>
    ConnectionNode(ref: r, label: r.id, diveCount: dives);
ConnectionEdge _e(NodeRef a, NodeRef b, int w) => ConnectionEdge(
  source: a,
  target: b,
  weight: w,
  firstDiveAt: DateTime.utc(2024),
  lastDiveAt: DateTime.utc(2024),
);

void main() {
  test('a two-kind map puts the bigger kind on the rows', () {
    final m = MatrixModel.of(
      ConnectionGraph(
        nodes: [_n(_s('reef'), 3), _n(_b('ann'), 5), _n(_b('bob'), 2)],
        edges: [_e(_b('ann'), _s('reef'), 3), _e(_b('bob'), _s('reef'), 1)],
      ),
    );
    expect(m.symmetric, isFalse);
    expect(m.rows.map((n) => n.ref.id), ['ann', 'bob']);
    expect(m.columns.map((n) => n.ref.id), ['reef']);
    expect(m.edgeAt(1, 0)?.weight, 1);
  });

  test('a same-kind link makes it symmetric with an empty diagonal', () {
    final m = MatrixModel.of(
      ConnectionGraph(
        nodes: [_n(_b('ann'), 5), _n(_b('bob'), 2), _n(_s('reef'), 1)],
        edges: [_e(_b('ann'), _b('bob'), 4), _e(_b('ann'), _s('reef'), 1)],
      ),
    );
    expect(m.symmetric, isTrue);
    expect(m.rows, m.columns);
    expect(m.rows.map((n) => n.ref.id), ['ann', 'bob', 'reef']);
    expect(m.edgeAt(0, 0), isNull);
    expect(m.edgeAt(0, 1)?.weight, 4);
    expect(m.edgeAt(1, 0)?.weight, 4);
    expect(m.maxWeight, 4);
  });

  test('hit testing maps points to headers and cells', () {
    expect(
      MatrixGeometry.hitAt(
        const Offset(
          MatrixGeometry.rowHeader + 5,
          MatrixGeometry.columnHeader + MatrixGeometry.cell + 5,
        ),
        scroll: Offset.zero,
        rows: 3,
        columns: 3,
      ),
      (row: 1, column: 0),
    );
    expect(
      MatrixGeometry.hitAt(
        const Offset(10, MatrixGeometry.columnHeader + 5),
        scroll: Offset.zero,
        rows: 3,
        columns: 3,
      ),
      (row: 0, column: null),
    );
    expect(
      MatrixGeometry.hitAt(
        const Offset(MatrixGeometry.rowHeader + 5, 10),
        scroll: const Offset(MatrixGeometry.cell, 0),
        rows: 3,
        columns: 3,
      ),
      (row: null, column: 1),
    );
    expect(
      MatrixGeometry.hitAt(
        const Offset(10, 10),
        scroll: Offset.zero,
        rows: 3,
        columns: 3,
      ),
      isNull,
    );
    expect(
      MatrixGeometry.hitAt(
        const Offset(
          MatrixGeometry.rowHeader + 5 * MatrixGeometry.cell,
          MatrixGeometry.columnHeader + 5,
        ),
        scroll: Offset.zero,
        rows: 3,
        columns: 3,
      ),
      isNull,
    );
  });
}
