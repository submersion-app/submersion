import 'package:submersion/features/connections/data/connections_reader.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/views/map_spec.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

/// A whole map: every entity of each chosen kind, and one edge query per
/// chosen link. Entities without a surviving line stay, as islands.
class MapLoader {
  const MapLoader(this._reader);

  final ConnectionsReader _reader;

  Future<ConnectionGraph> load(
    MapSpec spec, {
    required String? diverId,
    required DiveFilterState filter,
  }) async {
    final kinds = spec.kinds.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    final nodes = <ConnectionNode>[
      for (final k in kinds)
        ...await _reader.nodes(k, diverId: diverId, filter: filter),
    ];
    final links = spec.links.toList()..sort((a, b) => a.wire.compareTo(b.wire));
    final edges = <ConnectionEdge>[
      for (final l in links)
        ...await _reader.edges(
          l.a,
          l.b,
          diverId: diverId,
          filter: filter,
          minShared: spec.minSharedDives,
        ),
    ];
    return ConnectionGraph(nodes: nodes, edges: edges);
  }
}
