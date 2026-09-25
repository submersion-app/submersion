import 'package:flutter/material.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/lenses/connection_lens.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Names the data that feeds the lens, so an empty canvas is never a mystery.
class ConnectionsEmptyState extends StatelessWidget {
  const ConnectionsEmptyState({
    super.key,
    required this.lens,
    required this.hasAnyDives,
    this.hasActiveFilter = false,
  });

  final LensSelection lens;
  final bool hasAnyDives;

  /// True when the diver's own filter is what emptied the graph; the message
  /// then blames the filter rather than missing data.
  final bool hasActiveFilter;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final involvesBuddies =
        lens.kindA == ConnectionKind.buddy ||
        lens.kindB == ConnectionKind.buddy;
    final text = !hasAnyDives
        ? l10n.connections_empty_noDives
        : hasActiveFilter
        ? l10n.connections_empty_filtered
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
