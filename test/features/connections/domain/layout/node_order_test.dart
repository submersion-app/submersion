import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/node_order.dart';

ConnectionNode _node(String id, String label, {int dives = 1}) =>
    ConnectionNode(
      ref: NodeRef(ConnectionKind.buddy, id),
      label: label,
      diveCount: dives,
    );

void main() {
  test('equally busy nodes order by label, accents folded (#4498)', () {
    final nodes = [
      _node('1', 'Joachim'),
      _node('2', 'zoé'),
      _node('3', 'Jérémie'),
      _node('4', 'Éric'),
    ]..sort(compareDivesLabel);

    expect(nodes.map((n) => n.label), ['Éric', 'Jérémie', 'Joachim', 'zoé']);
  });

  test('busier nodes still come first', () {
    final nodes = [_node('1', 'Anna'), _node('2', 'Zoé', dives: 5)]
      ..sort(compareDivesLabel);

    expect(nodes.map((n) => n.label), ['Zoé', 'Anna']);
  });
}
