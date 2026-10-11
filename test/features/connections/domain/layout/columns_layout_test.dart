import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/columns_layout.dart';
import 'package:submersion/features/connections/domain/layout/graph_point.dart';

ConnectionNode _n(ConnectionKind k, String id, int dives) =>
    ConnectionNode(ref: NodeRef(k, id), label: id, diveCount: dives);

void main() {
  test('one column per kind in kind order, busiest at the top', () {
    final f = ColumnsLayout.compute(
      nodes: [
        _n(ConnectionKind.site, 's1', 1),
        _n(ConnectionKind.buddy, 'b1', 2),
        _n(ConnectionKind.buddy, 'b2', 7),
      ],
    );
    expect(
      f.positions[const NodeRef(ConnectionKind.buddy, 'b2')],
      GraphPoint.zero,
    );
    expect(
      f.positions[const NodeRef(ConnectionKind.buddy, 'b1')],
      const GraphPoint(0, ColumnsLayout.rowGap),
    );
    expect(
      f.positions[const NodeRef(ConnectionKind.site, 's1')],
      const GraphPoint(ColumnsLayout.columnGap, 0),
    );
  });

  test(
    'a tall column wraps into sub-columns and pushes the next kind right',
    () {
      final sites = [
        for (var i = 0; i < 30; i++) _n(ConnectionKind.site, 's$i', 100 - i),
      ];
      final f = ColumnsLayout.compute(
        nodes: [...sites, _n(ConnectionKind.trip, 't', 1)],
      );
      expect(
        f.positions[sites[25].ref],
        const GraphPoint(ColumnsLayout.subColumnGap, 0),
      );
      expect(
        f.positions[const NodeRef(ConnectionKind.trip, 't')],
        const GraphPoint(
          ColumnsLayout.subColumnGap + ColumnsLayout.columnGap,
          0,
        ),
      );
    },
  );

  test('around: the focus kind comes first and the focus tops it', () {
    final me = _n(ConnectionKind.site, 'home', 1);
    final f = ColumnsLayout.compute(
      nodes: [
        _n(ConnectionKind.buddy, 'b', 9),
        _n(ConnectionKind.site, 'x', 5),
        me,
      ],
      focus: me.ref,
    );
    expect(f.positions[me.ref], GraphPoint.zero);
    expect(f.positions[const NodeRef(ConnectionKind.site, 'x')]!.x, 0);
    expect(
      f.positions[const NodeRef(ConnectionKind.buddy, 'b')]!.x,
      ColumnsLayout.columnGap,
    );
  });

  test('spacing scales every gap', () {
    final f = ColumnsLayout.compute(
      nodes: [
        _n(ConnectionKind.buddy, 'a', 2),
        _n(ConnectionKind.buddy, 'b', 1),
      ],
      spacing: 2,
    );
    expect(
      f.positions[const NodeRef(ConnectionKind.buddy, 'b')],
      const GraphPoint(0, ColumnsLayout.rowGap * 2),
    );
  });
}
