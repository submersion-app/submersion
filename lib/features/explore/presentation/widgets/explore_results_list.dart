import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/compact_dive_list_tile.dart';
import 'package:submersion/features/explore/presentation/providers/explore_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The matching dives, via the compact tile the dive list already uses.
class ExploreResultsList extends ConsumerWidget {
  const ExploreResultsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(exploreResultsProvider);
    final count = ref.watch(exploreCountProvider).value ?? 0;
    return results.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) =>
          Padding(padding: const EdgeInsets.all(16), child: Text('$e')),
      data: (dives) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              context.l10n.explore_results_title,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          for (final d in dives)
            CompactDiveListTile(
              key: ValueKey('explore-result-${d.id}'),
              diveId: d.id,
              diveNumber: d.diveNumber ?? 0,
              dateTime: d.dateTime,
              siteName: d.siteName,
              maxDepth: d.maxDepth,
              duration: d.bottomTime,
              summary: d,
              onTap: () => context.push('/dives/${d.id}'),
            ),
          if (count > dives.length)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                context.l10n.explore_results_truncated(dives.length),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}
