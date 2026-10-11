import 'package:submersion/core/text/text_sort.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';

enum PairsColumn { a, b, shared, last, first }

enum EntitiesColumn { name, kind, dives, links, strongest, first }

/// One Entities table row: the node, how many nodes on the map it links to,
/// and the one it shares the most dives with.
class EntityRow {
  const EntityRow({
    required this.node,
    required this.links,
    this.strongest,
    this.strongestWeight = 0,
  });

  final ConnectionNode node;
  final int links;
  final ConnectionNode? strongest;
  final int strongestWeight;
}

/// Sorting for the Pairs and Entities tables. Names compare alphabetically,
/// ignoring case and accents. Ties always fall back to labels ascending, so
/// equal rows keep one order whichever way the column runs.
abstract final class ConnectionsTableRows {
  /// Text columns read A to Z first; numbers and dates biggest or newest
  /// first.
  static bool startsAscending(Enum column) =>
      column == PairsColumn.a ||
      column == PairsColumn.b ||
      column == EntitiesColumn.name ||
      column == EntitiesColumn.kind ||
      column == EntitiesColumn.strongest;

  /// The sort a table applies: [by] while its column is [shown], else
  /// [fallback] biggest first. The table keeps [by], so widening the view
  /// until its column shows again brings the diver's choice back.
  static (T, bool) shownSort<T extends Enum>(
    T by,
    bool ascending,
    Iterable<T> shown,
    T fallback,
  ) => shown.contains(by) ? (by, ascending) : (fallback, false);

  static List<ConnectionEdge> pairs(
    ConnectionGraph graph,
    PairsColumn by, {
    required bool ascending,
  }) {
    final labels = {for (final n in graph.nodes) n.ref: n.label};
    final collator = TextCollator();
    int byLabel(NodeRef x, NodeRef y) =>
        collator.compare(labels[x] ?? x.id, labels[y] ?? y.id);
    int tieBreak(ConnectionEdge x, ConnectionEdge y) {
      final a = byLabel(x.source, y.source);
      return a != 0 ? a : byLabel(x.target, y.target);
    }

    return [...graph.edges]..sort((x, y) {
      final primary = switch (by) {
        PairsColumn.a => byLabel(x.source, y.source),
        PairsColumn.b => byLabel(x.target, y.target),
        PairsColumn.shared => x.weight.compareTo(y.weight),
        PairsColumn.last => x.lastDiveAt.compareTo(y.lastDiveAt),
        PairsColumn.first => x.firstDiveAt.compareTo(y.firstDiveAt),
      };
      final ordered = ascending ? primary : -primary;
      return ordered != 0 ? ordered : tieBreak(x, y);
    });
  }

  static List<EntityRow> entities(
    ConnectionGraph graph,
    EntitiesColumn by, {
    required bool ascending,
  }) {
    final byRef = {for (final n in graph.nodes) n.ref: n};
    final links = <NodeRef, int>{};
    final best = <NodeRef, ConnectionEdge>{};
    for (final e in graph.edges) {
      for (final end in [e.source, e.target]) {
        links[end] = (links[end] ?? 0) + 1;
        final current = best[end];
        if (current == null || e.weight > current.weight) best[end] = e;
      }
    }
    final rows = [
      for (final n in graph.nodes)
        EntityRow(
          node: n,
          links: links[n.ref] ?? 0,
          strongest: switch (best[n.ref]) {
            final e? => byRef[e.otherEnd(n.ref)],
            null => null,
          },
          strongestWeight: best[n.ref]?.weight ?? 0,
        ),
    ];
    final collator = TextCollator();
    // A missing date sorts as the oldest.
    int compareDates(DateTime? x, DateTime? y) {
      if (x == null || y == null) {
        return (x == null ? 0 : 1) - (y == null ? 0 : 1);
      }
      return x.compareTo(y);
    }

    return rows..sort((x, y) {
      final primary = switch (by) {
        EntitiesColumn.name => collator.compare(x.node.label, y.node.label),
        EntitiesColumn.kind => x.node.ref.kind.index.compareTo(
          y.node.ref.kind.index,
        ),
        EntitiesColumn.dives => x.node.diveCount.compareTo(y.node.diveCount),
        EntitiesColumn.links => x.links.compareTo(y.links),
        EntitiesColumn.strongest => collator.compare(
          x.strongest?.label ?? '',
          y.strongest?.label ?? '',
        ),
        EntitiesColumn.first => compareDates(
          x.node.firstDiveAt,
          y.node.firstDiveAt,
        ),
      };
      final ordered = ascending ? primary : -primary;
      return ordered != 0
          ? ordered
          : collator.compare(x.node.label, y.node.label);
    });
  }
}
