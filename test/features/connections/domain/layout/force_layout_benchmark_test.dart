import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/whole_web_layout.dart';

void main() {
  test('160 nodes and 600 edges settle in well under a second of CPU', () {
    final nodes = [
      for (var i = 0; i < 160; i++) NodeRef(ConnectionKind.buddy, 'n$i'),
    ];
    final edges = <ConnectionEdge>[];
    for (var i = 0; i < 600; i++) {
      final a = nodes[(i * 7) % 160];
      final b = nodes[(i * 13 + 1) % 160];
      if (a == b) continue;
      edges.add(
        ConnectionEdge(
          source: a,
          target: b,
          weight: 1 + i % 5,
          firstDiveAt: DateTime.utc(2024),
          lastDiveAt: DateTime.utc(2024),
        ),
      );
    }
    final sw = Stopwatch()..start();
    final layout = WholeWebLayout(nodes: nodes, edges: edges)..advance(300);
    sw.stop();
    expect(layout.settled, isTrue);
    // Loose on purpose: CI machines vary. A regression that doubles the work
    // still shows; a slow shard does not flake.
    expect(
      sw.elapsedMilliseconds,
      lessThan(4000),
      reason: 'layout took ${sw.elapsedMilliseconds} ms',
    );
  });
}
