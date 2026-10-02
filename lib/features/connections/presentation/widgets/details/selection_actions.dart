import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/presentation/providers/connections_selection_provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_view_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Show dives at full width, with Open and Centre here sharing the row
/// beneath it. Fixed rows rather than a Wrap, so the buttons never wrap
/// into each other in the narrow panel.
class SelectionActions extends ConsumerWidget {
  const SelectionActions({
    super.key,
    required this.diveIds,
    this.openRoute,
    this.focus,
  });

  final List<String> diveIds;

  /// The selected entity's detail page, when its kind has one.
  final String? openRoute;

  /// The node Centre here centres on; null for a line.
  final NodeRef? focus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final route = openRoute;
    final node = focus;
    final secondary = [
      if (route != null)
        OutlinedButton.icon(
          key: const ValueKey('connections-action-open'),
          icon: const Icon(Icons.open_in_new),
          label: Text(l10n.connections_action_open),
          onPressed: () => context.push(route),
        ),
      if (node != null)
        OutlinedButton.icon(
          key: const ValueKey('connections-action-centre'),
          icon: const Icon(Icons.center_focus_strong),
          label: Text(l10n.connections_action_centreHere),
          onPressed: () {
            ref
                .read(connectionsViewProvider.notifier)
                .update((s) => s.centreOn(node));
            ref.read(connectionsSelectionProvider.notifier).state =
                NodeSelection(node);
          },
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          key: const ValueKey('connections-action-showDives'),
          icon: const Icon(Icons.list),
          label: Text(l10n.connections_action_showDives),
          onPressed: diveIds.isEmpty
              ? null
              : () {
                  ref.read(diveFilterProvider.notifier).state = DiveFilterState(
                    diveIds: diveIds,
                  );
                  context.go('/dives');
                },
        ),
        if (secondary.isNotEmpty) ...[
          const SizedBox(height: 8),
          // Stretched, so a label that wraps keeps both buttons one height.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, button) in secondary.indexed) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: button),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
