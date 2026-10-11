import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/views/connections_display.dart';
import 'package:submersion/features/connections/presentation/providers/connections_display_provider.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// App bar menu switching the page between the graph and its tables. Its
/// items look like the list view toggle's: icon and label, the current one
/// in the primary colour.
class ViewModeButton extends ConsumerWidget {
  const ViewModeButton({super.key});

  static IconData iconFor(ConnectionsViewKind view) => switch (view) {
    ConnectionsViewKind.graph => Icons.hub_outlined,
    ConnectionsViewKind.pairs => Icons.compare_arrows,
    ConnectionsViewKind.entities => Icons.format_list_bulleted,
    ConnectionsViewKind.matrix => Icons.grid_on,
  };

  static String labelFor(AppLocalizations l10n, ConnectionsViewKind view) =>
      switch (view) {
        ConnectionsViewKind.graph => l10n.connections_view_graph,
        ConnectionsViewKind.pairs => l10n.connections_view_pairs,
        ConnectionsViewKind.entities => l10n.connections_view_entities,
        ConnectionsViewKind.matrix => l10n.connections_view_matrix,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final primary = Theme.of(context).colorScheme.primary;
    final view = ref.watch(connectionsDisplayProvider.select((d) => d.view));
    return PopupMenuButton<ConnectionsViewKind>(
      key: const ValueKey('connections-view-button'),
      icon: Icon(iconFor(view)),
      tooltip: l10n.connections_view_tooltip,
      initialValue: view,
      onSelected: (v) => ref
          .read(connectionsDisplayProvider.notifier)
          .update((d) => d.copyWith(view: v)),
      itemBuilder: (context) => [
        for (final v in ConnectionsViewKind.values)
          PopupMenuItem(
            value: v,
            child: Row(
              children: [
                Icon(iconFor(v), size: 20, color: v == view ? primary : null),
                const SizedBox(width: 12),
                Text(
                  labelFor(l10n, v),
                  style: v == view
                      ? TextStyle(color: primary, fontWeight: FontWeight.w600)
                      : null,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
