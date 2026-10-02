import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/views/graph_summary.dart';
import 'package:submersion/features/connections/presentation/canvas/connection_kind_colors.dart';
import 'package:submersion/features/connections/presentation/panel/entity_search_field.dart';
import 'package:submersion/features/connections/presentation/providers/connections_view_provider.dart';
import 'package:submersion/features/connections/presentation/widgets/connections_legend.dart';
import 'package:submersion/l10n/l10n_extension.dart';

class AroundControls extends ConsumerWidget {
  const AroundControls({super.key, required this.graph});

  final ConnectionGraph graph;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = ConnectionKindColors.of(context);
    final view = ref.watch(connectionsViewProvider);
    final notifier = ref.read(connectionsViewProvider.notifier);
    final focus = view.focus;
    final counts = GraphSummary.of(graph, focus: focus).countsByKind;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const EntitySearchField(),
        if (focus != null) ...[
          const SizedBox(height: 12),
          Text(
            l10n.connections_around_centredOn,
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              CircleAvatar(
                radius: 6,
                backgroundColor: colors.colorFor(focus.kind),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  graph.nodeFor(focus)?.label ?? focus.id,
                  style: theme.textTheme.titleSmall,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        Text(l10n.connections_around_hops, style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        SegmentedButton<int>(
          key: const ValueKey('hops'),
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 1, label: Text('1')),
            ButtonSegment(value: 2, label: Text('2')),
            ButtonSegment(value: 3, label: Text('3')),
          ],
          selected: {view.hops},
          onSelectionChanged: (s) =>
              notifier.update((v) => v.withHops(s.single)),
        ),
        const SizedBox(height: 12),
        Text(l10n.connections_around_show, style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final k in ConnectionKind.values)
              FilterChip(
                key: ValueKey('around-kind-${k.name}'),
                avatar: CircleAvatar(
                  radius: 5,
                  backgroundColor: colors.colorFor(k),
                ),
                label: Text(
                  l10n.connections_around_kindChip(
                    kindLabel(l10n, k),
                    // What the budget cut still exists around the centre.
                    (counts[k] ?? 0) + (graph.hiddenByKind[k] ?? 0),
                  ),
                ),
                selected: view.aroundKinds.contains(k),
                onSelected: (on) => notifier.update(
                  (v) => v.withAroundKinds(
                    on
                        ? {...v.aroundKinds, k}
                        : ({...v.aroundKinds}..remove(k)),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
