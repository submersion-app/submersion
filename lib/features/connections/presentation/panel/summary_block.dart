import 'package:flutter/material.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/views/graph_summary.dart';
import 'package:submersion/features/connections/presentation/canvas/connection_kind_colors.dart';
import 'package:submersion/features/connections/presentation/widgets/connections_legend.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Counts per kind (with their colour, so it doubles as the legend), the
/// number of connections, and the standouts of the map in view.
class SummaryBlock extends StatelessWidget {
  const SummaryBlock({super.key, required this.graph, this.focus});

  final ConnectionGraph graph;
  final NodeRef? focus;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = ConnectionKindColors.of(context);
    final s = GraphSummary.of(graph, focus: focus);
    final kinds = s.countsByKind.keys.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    String label(NodeRef r) => graph.nodeFor(r)?.label ?? r.id;
    Widget row(String left, String right, {Color? dot}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          if (dot != null) ...[
            CircleAvatar(radius: 5, backgroundColor: dot),
            const SizedBox(width: 6),
          ],
          Expanded(child: Text(left, style: theme.textTheme.bodySmall)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              right,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.connections_summary_title, style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        if (focus != null)
          row(l10n.connections_summary_entitiesAround(s.entitiesAround), ''),
        for (final ConnectionKind k in kinds)
          row(
            kindLabel(l10n, k),
            '${s.countsByKind[k]}',
            dot: colors.colorFor(k),
          ),
        row(l10n.connections_filterBar_edges(s.connectionCount), ''),
        if (focus != null && s.closest != null)
          row(
            l10n.connections_summary_closest,
            '${s.closest!.label}, '
            '${l10n.connections_selection_divesTogether(s.closestWeight)}',
          ),
        if (focus == null && s.mostConnected != null)
          row(l10n.connections_summary_mostConnected, s.mostConnected!.label),
        if (focus == null && s.strongest != null)
          row(
            l10n.connections_summary_strongestPair,
            l10n.connections_summary_pairValue(
              s.strongest!.weight,
              label(s.strongest!.source),
              label(s.strongest!.target),
            ),
          ),
      ],
    );
  }
}
