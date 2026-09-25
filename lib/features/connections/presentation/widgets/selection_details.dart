import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/presentation/providers/connections_providers.dart';
import 'package:submersion/features/connections/presentation/providers/connections_selection_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_roles/presentation/providers/dive_role_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Body shared by the compact bottom card and the wide side panel.
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
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));
    final roles = ref.watch(diveRoleMapProvider).value;
    final ids =
        ref.watch(connectionsSelectionDiveIdsProvider(selection)).value ??
        const <String>[];

    String? subtitleOf(NodeSubtitle? s) => switch (s) {
      null => null,
      TextSubtitle(:final text) => text,
      DateRangeSubtitle(:final start, :final end) => units.formatDateRange(
        start,
        end,
        l10n: l10n,
      ),
      RoleSubtitle(:final roleId) => roles?[roleId]?.name,
    };

    final String title;
    final String? subtitle;
    final String countText;
    final NodeRef? focusRef;
    final String? openRoute;
    final List<Widget> connections;

    switch (selection) {
      case NodeSelection(:final ref):
        final node = graph.nodeFor(ref);
        title = node?.label ?? ref.id;
        subtitle = subtitleOf(node?.subtitle);
        countText = l10n.connections_selection_dives(node?.diveCount ?? 0);
        focusRef = ref;
        openRoute = ref.kind.detailRoute(ref.id);
        final top = graph.edgesOf(ref)
          ..sort((a, b) => b.weight.compareTo(a.weight));
        connections = [
          for (final e in top.take(5))
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(
                graph.nodeFor(e.otherEnd(ref)!)?.label ?? e.otherEnd(ref)!.id,
              ),
              trailing: Text(
                l10n.connections_selection_divesTogether(e.weight),
              ),
            ),
        ];
      case EdgeSelection(:final a, :final b):
        final edge = graph.edges
            .where((e) => e.touches(a) && e.touches(b))
            .firstOrNull;
        title =
            '${graph.nodeFor(a)?.label ?? a.id}  &  '
            '${graph.nodeFor(b)?.label ?? b.id}';
        subtitle = edge == null
            ? null
            : l10n.connections_selection_firstLast(
                units.formatDate(edge.firstDiveAt),
                units.formatDate(edge.lastDiveAt),
              );
        countText = l10n.connections_selection_divesTogether(edge?.weight ?? 0);
        focusRef = null;
        openRoute = null;
        connections = const [];
    }

    final route = openRoute;
    final focus = focusRef;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        if (subtitle != null)
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        const SizedBox(height: 4),
        Text(countText, style: theme.textTheme.bodyMedium),
        if (connections.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            l10n.connections_selection_topConnections,
            style: theme.textTheme.labelLarge,
          ),
          ...connections,
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            if (route != null)
              OutlinedButton.icon(
                icon: const Icon(Icons.open_in_new),
                label: Text(l10n.connections_action_open),
                onPressed: () => context.push(route),
              ),
            if (focus != null)
              OutlinedButton.icon(
                icon: const Icon(Icons.center_focus_strong),
                label: Text(l10n.connections_action_focus),
                onPressed: () {
                  ref.read(connectionsFocusProvider.notifier).state = focus;
                  ref.read(connectionsSelectionProvider.notifier).state =
                      NodeSelection(focus);
                },
              ),
            FilledButton.icon(
              icon: const Icon(Icons.list),
              label: Text(l10n.connections_action_showDives),
              onPressed: ids.isEmpty
                  ? null
                  : () {
                      ref.read(diveFilterProvider.notifier).state =
                          DiveFilterState(diveIds: ids);
                      context.go('/dives');
                    },
            ),
          ],
        ),
      ],
    );
  }
}
