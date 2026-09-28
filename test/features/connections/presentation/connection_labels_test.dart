import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/presentation/connection_labels.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  final de = lookupAppLocalizations(const Locale('de'));
  final en = lookupAppLocalizations(const Locale('en'));

  test('a built-in species reads in the diver\'s language', () {
    expect(
      connectionNodeLabel(
        de,
        const NodeRef(ConnectionKind.species, 'sp_whale_shark'),
        'Whale Shark',
      ),
      de.species_whale_shark_name,
    );
  });

  test('a custom species keeps the name the diver typed', () {
    expect(
      connectionNodeLabel(
        de,
        const NodeRef(ConnectionKind.species, '6f1c2d34-aaaa'),
        'Stove-pipe Sponge',
      ),
      'Stove-pipe Sponge',
    );
  });

  test('a built-in dive type is translated; a custom one on its slug is '
      'not', () {
    const ref = NodeRef(ConnectionKind.diveType, 'recreational');
    expect(
      connectionNodeLabel(de, ref, en.diveType_builtin_recreational),
      de.diveType_builtin_recreational,
    );
    expect(connectionNodeLabel(de, ref, 'My fun dives'), 'My fun dives');
  });

  test('other kinds keep their stored label', () {
    expect(
      connectionNodeLabel(
        de,
        const NodeRef(ConnectionKind.buddy, 'b1'),
        'Kiyan Griffin',
      ),
      'Kiyan Griffin',
    );
  });

  test('a graph with nothing to translate is returned as is', () {
    const graph = ConnectionGraph(
      nodes: [
        ConnectionNode(
          ref: NodeRef(ConnectionKind.buddy, 'b1'),
          label: 'Kiyan',
          diveCount: 3,
        ),
      ],
      edges: [],
    );
    expect(identical(localizeGraph(graph, de), graph), isTrue);
  });

  test('a graph with a built-in species gets the translated label', () {
    const graph = ConnectionGraph(
      nodes: [
        ConnectionNode(
          ref: NodeRef(ConnectionKind.species, 'sp_whale_shark'),
          label: 'Whale Shark',
          diveCount: 3,
        ),
      ],
      edges: [],
    );
    expect(
      localizeGraph(graph, de).nodes.single.label,
      de.species_whale_shark_name,
    );
  });
}
