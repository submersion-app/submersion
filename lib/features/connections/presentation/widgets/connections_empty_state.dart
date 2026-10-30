import 'package:flutter/material.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/views/connections_view_state.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Names the data that feeds the view, so an empty canvas is never a
/// mystery. Around mode with no centre yet asks for one instead.
class ConnectionsEmptyState extends StatelessWidget {
  const ConnectionsEmptyState({
    super.key,
    required this.view,
    required this.hasAnyDives,
    this.hasActiveFilter = false,
    this.buddiesWithoutSites = false,
  });

  final ConnectionsViewState view;
  final bool hasAnyDives;

  /// True when the diver's own filter is what emptied the graph; the message
  /// then blames the filter rather than missing data.
  final bool hasActiveFilter;

  /// True when Who dives where found buddies on dives but no dive with both
  /// a buddy and a site; the message then asks for sites, not buddies.
  final bool buddiesWithoutSites;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final kinds = view.mode == ConnectionsMode.map
        ? view.mapSpec.kinds
        : view.aroundKinds;
    final involvesBuddies = kinds.contains(ConnectionKind.buddy);
    final text = view.isAroundWithoutFocus
        ? l10n.connections_around_prompt
        : !hasAnyDives
        ? l10n.connections_empty_noDives
        : hasActiveFilter
        ? l10n.connections_empty_filtered
        : buddiesWithoutSites
        ? l10n.connections_empty_whereNoSites
        : involvesBuddies
        ? l10n.connections_empty_buddies
        : l10n.connections_empty_sites;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.hub_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
