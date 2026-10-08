import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/views/graph_summary.dart';
import 'package:submersion/features/connections/presentation/providers/connections_providers.dart';
import 'package:submersion/features/connections/presentation/providers/connections_selection_provider.dart';
import 'package:submersion/features/connections/presentation/widgets/details/detail_stat_tiles.dart';
import 'package:submersion/features/connections/presentation/widgets/details/kind_tag.dart';
import 'package:submersion/features/connections/presentation/widgets/details/selection_actions.dart';
import 'package:submersion/features/connections/presentation/widgets/details/top_connection_row.dart';
import 'package:submersion/features/dive_roles/presentation/providers/dive_role_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Details tab's body for a selected node or line, in the wide side
/// panel and in the phone sheet alike.
class GraphSelectionDetails extends ConsumerWidget {
  const GraphSelectionDetails({
    super.key,
    required this.graph,
    required this.selection,
  });

  final ConnectionGraph graph;
  final GraphSelection selection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids =
        ref.watch(connectionsSelectionDiveIdsProvider(selection)).value ??
        const <String>[];
    return switch (selection) {
      NodeSelection(:final ref) => _NodeDetails(
        graph: graph,
        node: ref,
        diveIds: ids,
      ),
      EdgeSelection(:final a, :final b) => _EdgeDetails(
        graph: graph,
        a: a,
        b: b,
        diveIds: ids,
      ),
    };
  }
}

class _NodeDetails extends ConsumerWidget {
  const _NodeDetails({
    required this.graph,
    required this.node,
    required this.diveIds,
  });

  final ConnectionGraph graph;
  final NodeRef node;
  final List<String> diveIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));
    final roles = ref.watch(diveRoleMapProvider).value;
    final entity = graph.nodeFor(node);
    final subtitle = switch (entity?.subtitle) {
      null => null,
      TextSubtitle(:final text) => text,
      DateRangeSubtitle(:final start, :final end) => units.formatDateRange(
        start,
        end,
        l10n: l10n,
      ),
      RoleSubtitle(:final roleId) => roles?[roleId]?.name,
    };
    final edges = graph.edgesOf(node)..sort(GraphSummary.strongestFirst);
    final top = edges.take(5).toList();
    final strongest = top.isEmpty ? 0 : top.first.weight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        KindTag(
          key: const ValueKey('connections-details-kind'),
          kind: node.kind,
        ),
        const SizedBox(height: 4),
        Text(entity?.label ?? node.id, style: theme.textTheme.titleLarge),
        if (subtitle != null)
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        const SizedBox(height: 12),
        DetailStatTiles(
          stats: [
            DetailStat(
              id: 'dives',
              value: '${entity?.diveCount ?? 0}',
              label: l10n.connections_details_dives,
            ),
            DetailStat(
              id: 'connections',
              value: '${edges.length}',
              label: l10n.connections_details_connections,
            ),
          ],
        ),
        const SizedBox(height: 12),
        SelectionActions(
          diveIds: diveIds,
          openRoute: node.kind.detailRoute(node.id),
          focus: node,
        ),
        if (top.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            l10n.connections_selection_topConnections,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          for (final e in top) _topRow(ref, e, strongest),
        ],
      ],
    );
  }

  Widget _topRow(WidgetRef ref, ConnectionEdge e, int strongest) {
    final other = e.otherEnd(node)!;
    return TopConnectionRow(
      key: ValueKey('connections-top-${other.wire}'),
      kind: other.kind,
      label: graph.nodeFor(other)?.label ?? other.id,
      weight: e.weight,
      fraction: strongest == 0 ? 0 : e.weight / strongest,
      onTap: () => ref.read(connectionsSelectionProvider.notifier).state =
          EdgeSelection(e.source, e.target),
    );
  }
}

class _EdgeDetails extends ConsumerWidget {
  const _EdgeDetails({
    required this.graph,
    required this.a,
    required this.b,
    required this.diveIds,
  });

  final ConnectionGraph graph;
  final NodeRef a;
  final NodeRef b;
  final List<String> diveIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final edge = graph.edges
        .where((e) => e.touches(a) && e.touches(b))
        .firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Column(
          key: const ValueKey('connections-details-ends'),
          children: [
            KindedName(kind: a.kind, label: graph.nodeFor(a)?.label ?? a.id),
            const SizedBox(height: 8),
            KindedName(kind: b.kind, label: graph.nodeFor(b)?.label ?? b.id),
          ],
        ),
        const SizedBox(height: 12),
        DetailStatTiles(
          stats: [
            DetailStat(
              id: 'dives',
              value: '${edge?.weight ?? 0}',
              label: l10n.connections_details_dives,
            ),
            if (edge != null) ...[
              DetailStat(
                id: 'first',
                value: units.formatDate(edge.firstDiveAt),
                label: l10n.connections_details_first,
              ),
              DetailStat(
                id: 'last',
                value: units.formatDate(edge.lastDiveAt),
                label: l10n.connections_details_last,
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        SelectionActions(diveIds: diveIds),
      ],
    );
  }
}
