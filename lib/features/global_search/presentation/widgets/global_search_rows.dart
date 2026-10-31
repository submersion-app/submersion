import 'package:flutter/material.dart';

import 'package:submersion/core/constants/card_color.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/data/visibility/item_sharing.dart';
import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/buddies/presentation/widgets/compact_buddy_list_tile.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_list_content.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/courses/presentation/widgets/course_card.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/compact_dive_center_list_tile.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/formatters/dive_type_label_resolver.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_item.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/compact_site_list_tile.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/divers/presentation/providers/item_shares_providers.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/presentation/document_l10n.dart';
import 'package:submersion/features/documents/presentation/providers/document_providers.dart';
import 'package:submersion/features/documents/presentation/widgets/document_tile.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_list_content.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_set_tile.dart';
import 'package:submersion/features/global_search/domain/global_search_models.dart';
import 'package:submersion/features/global_search/presentation/providers/global_search_providers.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_log_providers.dart';
import 'package:submersion/features/gps_log/presentation/widgets/gps_track_list_tile.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/providers/seen_species_providers.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/marine_life/presentation/widgets/seen_species_tile.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_catalog_tile.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_list_row.dart';
import 'package:submersion/features/planner/presentation/providers/plan_repository_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/saved_plans_list.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/providers/tag_link_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/compact_trip_list_tile.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A section's records (#3882), each drawn by the row its own list draws and
/// read from the provider that list reads, so a result looks like the list
/// it came from and stays as current as it is. Compact where a list offers
/// the choice: search shows several types at once.
class GlobalSearchRows extends ConsumerWidget {
  const GlobalSearchRows({
    super.key,
    required this.kind,
    required this.ids,
    required this.onOpen,
  });

  final GlobalSearchKind kind;

  /// In the order to show them.
  final List<String> ids;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(unitFormatterProvider);
    return switch (kind) {
      GlobalSearchKind.dives => _rows(
        ref.watch(globalSearchDivesProvider(globalSearchDiveKey(ids))),
        (dive) => dive.id,
        (dives) => _DiveRows(dives: dives, onOpen: onOpen),
      ),
      GlobalSearchKind.sites => _each(
        ref.watch(sitesWithCountsProvider),
        (entry) => entry.site.id,
        (entry, onTap) => _SiteRow(entry: entry, onTap: onTap),
      ),
      GlobalSearchKind.trips => _each(
        ref.watch(allTripsWithStatsProvider),
        (entry) => entry.trip.id,
        (entry, onTap) => _TripRow(entry: entry, onTap: onTap),
      ),
      GlobalSearchKind.equipment => _each(
        ref.watch(allEquipmentProvider),
        (item) => item.id,
        (item, onTap) => EquipmentListTile(item: item, onTap: onTap),
      ),
      GlobalSearchKind.equipmentSets => _each(
        ref.watch(equipmentSetsProvider),
        (set) => set.id,
        (set, onTap) => EquipmentSetTile(set: set, onTap: onTap),
      ),
      GlobalSearchKind.buddies => _each(
        ref.watch(allBuddiesWithDiveCountProvider),
        (entry) => entry.buddy.id,
        (entry, onTap) => CompactBuddyListTile(entry: entry, onTap: onTap),
      ),
      GlobalSearchKind.diveCenters => _each(
        ref.watch(allDiveCentersProvider),
        (center) => center.id,
        (center, onTap) => _DiveCenterRow(center: center, onTap: onTap),
      ),
      GlobalSearchKind.certifications => _each(
        ref.watch(allCertificationsProvider),
        (certification) => certification.id,
        (certification, onTap) =>
            CertificationListTile(certification: certification, onTap: onTap),
      ),
      GlobalSearchKind.courses => _each(
        ref.watch(allCoursesProvider),
        (course) => course.id,
        (course, onTap) => CourseCard(course: course, onTap: onTap),
      ),
      GlobalSearchKind.species => _each(
        ref.watch(allSpeciesProvider),
        (species) => species.id,
        (species, onTap) => _SpeciesRow(species: species, onTap: onTap),
      ),
      GlobalSearchKind.documents => _each(
        ref.watch(allDocumentsProvider),
        (entry) => entry.document.id,
        (entry, onTap) => _DocumentRow(entry: entry, onTap: onTap),
      ),
      GlobalSearchKind.divePlans => _each(
        ref.watch(divePlanSummariesProvider),
        (plan) => plan.id,
        (plan, onTap) => SavedPlanTile(plan: plan, units: units, onTap: onTap),
      ),
      GlobalSearchKind.gpsTracks => _each(
        ref.watch(gpsTracksProvider),
        (track) => track.id,
        (track, onTap) => GpsTrackListTile(track: track, onTap: onTap),
      ),
      GlobalSearchKind.underwaterRoutes => _each(
        ref.watch(allNavTracksProvider),
        (route) => route.id,
        (route, onTap) =>
            NavTrackListRow(route: route, units: units, onTap: onTap),
      ),
    };
  }

  /// [records] in [ids]' order, for [build] to draw. A record the search
  /// found and the list no longer holds is left out: it has just gone.
  Widget _rows<T>(
    AsyncValue<List<T>> records,
    String Function(T record) idOf,
    Widget Function(List<T> shown) build,
  ) {
    if (records.hasError) return const _RowsFailed();
    if (!records.hasValue) return _RowsLoading(count: ids.length);
    final byId = {for (final r in records.requireValue) idOf(r): r};
    return build([for (final id in ids) ?byId[id]]);
  }

  /// [_rows], one record's tile at a time.
  Widget _each<T>(
    AsyncValue<List<T>> records,
    String Function(T record) idOf,
    Widget Function(T record, VoidCallback onTap) tile,
  ) => _rows(
    records,
    idOf,
    (shown) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final record in shown)
          KeyedSubtree(
            key: globalSearchRowKey(kind, idOf(record)),
            child: tile(record, () => onOpen(idOf(record))),
          ),
      ],
    ),
  );
}

/// Finds a result's row, for tests.
Key globalSearchRowKey(GlobalSearchKind kind, String id) =>
    ValueKey('global-search-hit-${kind.name}-$id');

/// Holds the rows' place while their records load, so what is below them
/// does not jump. Empty: a list's provider is normally already loaded, and a
/// spinner would only flash.
class _RowsLoading extends StatelessWidget {
  const _RowsLoading({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => SizedBox(height: count * 72.0);
}

class _RowsFailed extends StatelessWidget {
  const _RowsFailed();

  @override
  Widget build(BuildContext context) => ListTile(
    leading: const Icon(Icons.error_outline),
    title: Text(context.l10n.globalSearch_failed),
  );
}

/// As the Dives list: the card colours spread across the rows on show.
class _DiveRows extends ConsumerWidget {
  const _DiveRows({required this.dives, required this.onOpen});

  final List<DiveSummary> dives;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (attribute, preset, customStart, customEnd) = ref.watch(
      settingsProvider.select(
        (s) => (
          s.cardColorAttribute,
          s.cardColorGradientPreset,
          s.cardColorGradientStart,
          s.cardColorGradientEnd,
        ),
      ),
    );
    final values = dives
        .map((d) => getCardColorValue(d, attribute))
        .whereType<double>();
    final gradient = resolveGradientColors(
      presetName: preset,
      customStart: customStart,
      customEnd: customEnd,
    );
    final label = watchDiveTypeLabelResolver(ref, context.l10n);
    final shortLabel = watchDiveTypeShortLabelResolver(ref, context.l10n);
    final listed = watchDiveTypeListVisibilityPredicate(ref);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (index, dive) in dives.indexed)
          DiveListItem(
            key: globalSearchRowKey(GlobalSearchKind.dives, dive.id),
            summary: dive,
            viewMode: ListViewMode.compact,
            diveNumber: dive.diveNumber ?? index + 1,
            diveTypeLabelResolver: label,
            diveTypeShortLabelResolver: shortLabel,
            diveTypeListVisibilityPredicate: listed,
            colorValue: getCardColorValue(dive, attribute),
            minValueInList: values.isEmpty
                ? null
                : values.reduce((a, b) => a < b ? a : b),
            maxValueInList: values.isEmpty
                ? null
                : values.reduce((a, b) => a > b ? a : b),
            gradientStartColor: gradient.start,
            gradientEndColor: gradient.end,
            onTap: () => onOpen(dive.id),
          ),
      ],
    );
  }
}

/// Whether the shared badge shows, as on the lists: only a household of
/// divers has anyone to share with.
bool _showsSharedBadge(
  WidgetRef ref,
  SharedItemKind kind, {
  required String id,
  required bool everyone,
}) {
  final divers = ref.watch(allDiversProvider).value?.length ?? 0;
  final named =
      ref.watch(itemIdsWithSharesProvider(kind)).value ?? const <String>{};
  return divers >= 2 &&
      isSharedWithAnyone(id: id, everyone: everyone, namedShares: named);
}

class _SiteRow extends ConsumerWidget {
  const _SiteRow({required this.entry, required this.onTap});

  final SiteWithDiveCount entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) => CompactSiteListTile(
    entry: entry,
    onTap: onTap,
    showSharedBadge: _showsSharedBadge(
      ref,
      SharedItemKind.site,
      id: entry.site.id,
      everyone: entry.site.isShared,
    ),
  );
}

class _TripRow extends ConsumerWidget {
  const _TripRow({required this.entry, required this.onTap});

  final TripWithStats entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) => CompactTripListTile(
    tripWithStats: entry,
    onTap: onTap,
    showSharedBadge: _showsSharedBadge(
      ref,
      SharedItemKind.trip,
      id: entry.trip.id,
      everyone: entry.trip.isShared,
    ),
  );
}

class _DiveCenterRow extends ConsumerWidget {
  const _DiveCenterRow({required this.center, required this.onTap});

  final DiveCenter center;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      CompactDiveCenterListTile(
        center: center,
        diveCount: ref.watch(diveCenterDiveCountProvider(center.id)).value ?? 0,
        onTap: onTap,
      );
}

/// A species the diver has logged reads as the logbook does, with its
/// sightings; any other as the catalog does, having none to show.
class _SpeciesRow extends ConsumerWidget {
  const _SpeciesRow({required this.species, required this.onTap});

  final Species species;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seen = ref
        .watch(seenSpeciesProvider)
        .value
        ?.where((entry) => entry.species.id == species.id)
        .firstOrNull;
    if (seen == null) {
      return SpeciesCatalogTile(species: species, onTap: onTap);
    }
    return SeenSpeciesTile(
      entry: seen,
      cover: ref.watch(speciesCoverMediaProvider).value?[species.id],
      onTap: onTap,
    );
  }
}

class _DocumentRow extends ConsumerWidget {
  const _DocumentRow({required this.entry, required this.onTap});

  final DocumentListEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(tagsByItemProvider(TagScope.documents)).value;
    return DocumentTile(
      document: entry.document,
      ownerLabel: entry.ownerText(ref.watch(unitFormatterProvider)),
      tags: tags?[entry.document.id] ?? const [],
      onTap: onTap,
    );
  }
}
