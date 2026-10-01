import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_query_providers.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_query_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/explore/domain/query_model.dart';
import 'package:submersion/features/explore/presentation/providers/explore_providers.dart';
import 'package:submersion/features/explore/presentation/providers/explore_subject_providers.dart';
import 'package:submersion/features/insights/presentation/providers/insights_filter_provider.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_query_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Where the answer goes next: the dive list or Statistics for dives, the
/// subject's own list otherwise, each shown the published query as its own
/// chips. Nothing to hand off when the sentence placed no condition.
class ExploreHandoffBar extends ConsumerWidget {
  const ExploreHandoffBar({super.key, required this.subject});
  final ParsedSubject subject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final node = ref.watch(exploreQueryNodeProvider);
    if (node == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    if (subject == ParsedSubject.dives) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                // The published query alone, which the dive list shows as
                // query chips: the live scope, so the handoff stays right if
                // anything else ever writes it.
                ref.read(diveFilterProvider.notifier).state = DiveFilterState(
                  query: ref.read(exploreQueryNodeProvider),
                );
                // go, not push: the handoff moves to a shell tab.
                context.go('/dives');
              },
              child: Text(l10n.explore_handoff_diveList),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: () {
                ref.read(insightsFilterProvider.notifier).state =
                    DiveFilterState(query: ref.read(exploreQueryNodeProvider));
                context.go('/insights');
              },
              child: Text(l10n.explore_handoff_insights),
            ),
          ),
        ],
      );
    }
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        key: const ValueKey('explore-handoff-list'),
        onPressed: () => context.go(_handoff(ref, node)),
        child: Text(l10n.explore_handoff_list),
      ),
    );
  }

  /// Writes [node] as the subject's list query and returns the list's
  /// route. The list's other axes start clear, so its chips show exactly
  /// what Explore understood.
  String _handoff(WidgetRef ref, QueryNode node) {
    switch (subject) {
      case ParsedSubject.sites:
        ref.read(siteFilterProvider.notifier).state = SiteFilterState(
          query: node,
        );
        return '/sites';
      case ParsedSubject.equipment:
        ref.read(equipmentFilterProvider.notifier).state =
            exploreEquipmentFilter(node);
        return '/equipment';
      case ParsedSubject.buddies:
        ref.read(buddyQueryProvider.notifier).state = node;
        return '/buddies';
      case ParsedSubject.species:
        ref.read(seenSpeciesQueryProvider.notifier).state = node;
        return '/species';
      case ParsedSubject.trips:
        ref.read(tripFilterProvider.notifier).state = TripFilterState(
          query: node,
        );
        return '/trips';
      case ParsedSubject.centers:
        ref.read(diveCenterQueryProvider.notifier).state = node;
        return '/dive-centers';
      case ParsedSubject.dives:
        throw StateError('dives hand off through their own buttons');
    }
  }
}
