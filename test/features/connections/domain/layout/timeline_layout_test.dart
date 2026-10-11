import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/graph_point.dart';
import 'package:submersion/features/connections/domain/layout/layout_guide.dart';
import 'package:submersion/features/connections/domain/layout/timeline_layout.dart';

ConnectionNode _n(ConnectionKind k, String id, int dives, int? year) =>
    ConnectionNode(
      ref: NodeRef(k, id),
      label: id,
      diveCount: dives,
      firstDiveAt: year == null ? null : DateTime.utc(year, 6, 1),
    );

void main() {
  test('x follows the first dive year, empty years keep their band', () {
    final f = TimelineLayout.compute(
      nodes: [
        _n(ConnectionKind.buddy, 'a', 1, 2020),
        _n(ConnectionKind.buddy, 'b', 1, 2022),
      ],
    );
    expect(f.positions[const NodeRef(ConnectionKind.buddy, 'a')]!.x, 0);
    expect(
      f.positions[const NodeRef(ConnectionKind.buddy, 'b')]!.x,
      2 * TimelineLayout.yearWidth,
    );
    final years = f.guides.whereType<YearGuide>().map((g) => g.year);
    expect(years, [2020, 2021, 2022]);
  });

  test('kinds get lanes in kind order, each with a lane guide', () {
    final f = TimelineLayout.compute(
      nodes: [
        _n(ConnectionKind.site, 's', 1, 2020),
        _n(ConnectionKind.buddy, 'b', 1, 2020),
      ],
    );
    final buddyY = f.positions[const NodeRef(ConnectionKind.buddy, 'b')]!.y;
    final siteY = f.positions[const NodeRef(ConnectionKind.site, 's')]!.y;
    expect(buddyY, lessThan(siteY));
    expect(f.guides.whereType<LaneGuide>().map((g) => g.kind), [
      ConnectionKind.buddy,
      ConnectionKind.site,
    ]);
  });

  test('a cell stacks busiest first', () {
    final f = TimelineLayout.compute(
      nodes: [
        _n(ConnectionKind.buddy, 'quiet', 1, 2020),
        _n(ConnectionKind.buddy, 'busy', 9, 2020),
      ],
    );
    expect(
      f.positions[const NodeRef(ConnectionKind.buddy, 'busy')],
      GraphPoint.zero,
    );
    expect(
      f.positions[const NodeRef(ConnectionKind.buddy, 'quiet')],
      const GraphPoint(0, TimelineLayout.rowGap),
    );
  });

  test('a node without a date joins the earliest band', () {
    final f = TimelineLayout.compute(
      nodes: [
        _n(ConnectionKind.buddy, 'dated', 1, 2019),
        _n(ConnectionKind.buddy, 'undated', 0, null),
      ],
    );
    expect(f.positions[const NodeRef(ConnectionKind.buddy, 'undated')]!.x, 0);
  });

  test('no dates at all: one band, no year guides, nothing NaN', () {
    final f = TimelineLayout.compute(
      nodes: [_n(ConnectionKind.buddy, 'x', 0, null)],
    );
    expect(f.guides.whereType<YearGuide>(), isEmpty);
    expect(f.positions.values.every((p) => p.isFinite), isTrue);
  });

  test('spacing scales the year bands', () {
    final f = TimelineLayout.compute(
      nodes: [
        _n(ConnectionKind.buddy, 'a', 1, 2020),
        _n(ConnectionKind.buddy, 'b', 1, 2021),
      ],
      spacing: 2,
    );
    expect(
      f.positions[const NodeRef(ConnectionKind.buddy, 'b')]!.x,
      TimelineLayout.yearWidth * 2,
    );
  });

  test('an empty graph lays out nothing', () {
    expect(TimelineLayout.compute(nodes: const []).positions, isEmpty);
  });
}
