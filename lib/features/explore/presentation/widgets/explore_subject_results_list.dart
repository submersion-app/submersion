import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_with_dive_count.dart';
import 'package:submersion/features/buddies/presentation/widgets/buddy_list_tile.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_list_content.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_with_dive_count.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_list_tile.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_list_content.dart';
import 'package:submersion/features/explore/domain/query_model.dart';
import 'package:submersion/features/explore/presentation/providers/explore_subject_providers.dart';
import 'package:submersion/features/marine_life/domain/entities/seen_species.dart';
import 'package:submersion/features/marine_life/presentation/widgets/seen_species_tile.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_list_content.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A non-dive answer's rows, each drawn by its own list's tile and opening
/// its own detail page. Ranked by dives in the scope (the provider's order).
class ExploreSubjectResultsList extends ConsumerWidget {
  const ExploreSubjectResultsList({super.key, required this.subject});
  final ParsedSubject subject;

  /// As many rows as the dive results show.
  static const _shown = 100;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(exploreSubjectRowsProvider);
    return rows.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      // The providers log the cause; the diver gets a sentence.
      error: (_, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text(context.l10n.common_error_tryAgain),
      ),
      data: (list) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              context.l10n.explore_results_subjectTitle,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          for (final row in list.take(_shown))
            KeyedSubtree(
              key: ValueKey('explore-row-${row.id}'),
              child: _tile(context, ref, row),
            ),
          if (list.length > _shown)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                context.l10n.explore_results_subjectTruncated(_shown),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, WidgetRef ref, ExploreSubjectRow row) {
    void open(String route) => context.push('$route/${row.id}');
    return switch (subject) {
      ParsedSubject.sites => SiteListTile(
        entry: row.item as SiteWithDiveCount,
        onTap: () => open('/sites'),
      ),
      ParsedSubject.equipment => EquipmentListTile(
        item: row.item as EquipmentItem,
        onTap: () => open('/equipment'),
      ),
      ParsedSubject.buddies => BuddyListTile(
        entry: row.item as BuddyWithDiveCount,
        onTap: () => open('/buddies'),
      ),
      ParsedSubject.species => SeenSpeciesTile(
        entry: row.item as SeenSpecies,
        cover: ref.watch(speciesCoverMediaProvider).value?[row.id],
        onTap: () => open('/species'),
      ),
      ParsedSubject.trips => TripListTile(
        tripWithStats: row.item as TripWithStats,
        onTap: () => open('/trips'),
      ),
      ParsedSubject.centers => DiveCenterListTile(
        center: row.item as DiveCenter,
        onTap: () => open('/dive-centers'),
      ),
      ParsedSubject.dives => const SizedBox.shrink(),
    };
  }
}
