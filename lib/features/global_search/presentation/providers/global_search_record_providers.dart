import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_with_dive_count.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_with_dive_count.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/presentation/providers/document_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_log_providers.dart';
import 'package:submersion/features/marine_life/domain/entities/seen_species.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/providers/seen_species_providers.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart';
import 'package:submersion/features/planner/presentation/providers/plan_repository_providers.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/providers/tag_link_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';

// The records behind a Global Search section's rows (issue #4247), each
// keyed by [globalSearchIdsKey] of the ids it shows. A section shows a
// handful, so each reads its list's own repository method narrowed to
// those ids, on the list's terms (diver, visibility, enrichment), and
// refreshes on the list's own ticks; reading the list's provider instead
// would load every record, and every aggregate, to draw five.
//
// autoDispose: the rows' ids change with every keystroke, and a family
// entry left behind for each would hold its records and its subscriptions.

List<String> _ids(String key) => key.split(',');

final globalSearchSitesProvider = FutureProvider.autoDispose
    .family<List<SiteWithDiveCount>, String>((ref, key) async {
      final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
      invalidateOnSiteListChanges(ref);
      return ref
          .watch(siteRepositoryProvider)
          .getSitesWithDiveCounts(diverId: diverId, ids: _ids(key));
    });

final globalSearchTripsProvider = FutureProvider.autoDispose
    .family<List<TripWithStats>, String>((ref, key) async {
      final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
      invalidateOnTripListChanges(ref);
      return ref
          .watch(tripRepositoryProvider)
          .getAllTripsWithStats(diverId: diverId, ids: _ids(key));
    });

final globalSearchEquipmentProvider = FutureProvider.autoDispose
    .family<List<EquipmentItem>, String>((ref, key) async {
      final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
      invalidateOnEquipmentListChanges(ref);
      return ref
          .watch(equipmentRepositoryProvider)
          .getAllEquipment(diverId: diverId, ids: _ids(key));
    });

final globalSearchEquipmentSetsProvider = FutureProvider.autoDispose
    .family<List<EquipmentSet>, String>((ref, key) async {
      final repository = ref.watch(equipmentSetRepositoryProvider);
      final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
      ref.invalidateSelfWhen(repository.watchSetChanges());
      return repository.getAllSets(diverId: diverId, ids: _ids(key));
    });

final globalSearchBuddiesProvider = FutureProvider.autoDispose
    .family<List<BuddyWithDiveCount>, String>((ref, key) async {
      final repository = ref.watch(buddyRepositoryProvider);
      final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
      invalidateOnBuddyDiveChanges(ref, repository);
      return repository.getAllBuddiesWithDiveCount(
        diverId: diverId,
        ids: _ids(key),
      );
    });

final globalSearchDiveCentersProvider = FutureProvider.autoDispose
    .family<List<DiveCenter>, String>((ref, key) async {
      final repository = ref.watch(diveCenterRepositoryProvider);
      final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
      ref.invalidateSelfWhen(repository.watchDiveCentersChanges());
      return repository.getAllDiveCenters(diverId: diverId, ids: _ids(key));
    });

/// Each shown center's dive count, as [diveCenterDiveCountsProvider] counts
/// it; a center with none is absent.
final globalSearchDiveCenterCountsProvider = FutureProvider.autoDispose
    .family<Map<String, int>, String>((ref, key) {
      ref.invalidateSelfWhen(
        ref.read(diveRepositoryProvider).watchDivesChanges(),
      );
      return ref
          .watch(diveCenterRepositoryProvider)
          .getDiveCountsByCenter(centerIds: _ids(key));
    });

final globalSearchCertificationsProvider = FutureProvider.autoDispose
    .family<List<Certification>, String>((ref, key) async {
      final repository = ref.watch(certificationRepositoryProvider);
      final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
      ref.invalidateSelfWhen(repository.watchCertificationsChanges());
      return repository.getAllCertifications(diverId: diverId, ids: _ids(key));
    });

final globalSearchCoursesProvider = FutureProvider.autoDispose
    .family<List<Course>, String>((ref, key) async {
      final repository = ref.watch(courseRepositoryProvider);
      final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
      ref.invalidateSelfWhen(repository.watchCoursesChanges());
      return repository.getAllCourses(diverId: diverId, ids: _ids(key));
    });

final globalSearchSpeciesProvider = FutureProvider.autoDispose
    .family<List<Species>, String>((ref, key) {
      final repository = ref.watch(speciesRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchSpeciesChanges());
      return repository.getAllSpecies(ids: _ids(key));
    });

/// The shown species the diver has logged, by id, as [seenSpeciesProvider]
/// counts them.
final globalSearchSeenSpeciesProvider = FutureProvider.autoDispose
    .family<Map<String, SeenSpecies>, String>((ref, key) async {
      final diverId = ref.watch(currentDiverIdProvider);
      invalidateOnSeenSpeciesChanges(ref);
      final seen = await ref
          .watch(seenSpeciesRepositoryProvider)
          .getSeenSpecies(diverId: diverId, speciesIds: _ids(key));
      return {for (final entry in seen) entry.species.id: entry};
    });

/// The shown species' covers, as [speciesCoverMediaProvider] picks them.
final globalSearchSpeciesCoversProvider = FutureProvider.autoDispose
    .family<Map<String, MediaItem>, String>((ref, key) {
      final diverId = ref.watch(currentDiverIdProvider);
      invalidateOnSpeciesCoverChanges(ref);
      return ref
          .watch(mediaSpeciesRepositoryProvider)
          .getCoverMediaBySpecies(diverId: diverId, speciesIds: _ids(key));
    });

final globalSearchDocumentsProvider = FutureProvider.autoDispose
    .family<List<DocumentListEntry>, String>((ref, key) async {
      invalidateOnDocumentListChanges(ref);
      final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
      if (diverId == null) return const [];
      return ref
          .watch(documentRepositoryProvider)
          .getAllForDiver(diverId, ids: _ids(key));
    });

/// The shown documents' tags, as [tagsByItemProvider] reads them.
final globalSearchDocumentTagsProvider = FutureProvider.autoDispose
    .family<Map<String, List<Tag>>, String>((ref, key) {
      final repository = ref.watch(
        tagLinkRepositoryProvider(TagScope.documents),
      );
      ref.invalidateSelfWhen(repository.watchChanges());
      return repository.getTagsByItem(itemIds: _ids(key));
    });

/// The shown plans, and the rest of each one's saved series, which its row
/// counts.
final globalSearchDivePlansProvider = FutureProvider.autoDispose
    .family<List<DivePlanSummary>, String>((ref, key) {
      final repository = ref.watch(divePlanRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchPlanSummaryChanges());
      return repository.getAllPlanSummaries(ids: _ids(key));
    });

final globalSearchGpsTracksProvider = FutureProvider.autoDispose
    .family<List<GpsTrack>, String>((ref, key) {
      final repository = ref.watch(gpsTrackRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchTracksChanges());
      return repository.getCompletedTracks(ids: _ids(key));
    });

final globalSearchUnderwaterRoutesProvider = FutureProvider.autoDispose
    .family<List<NavTrack>, String>((ref, key) async {
      final repository = ref.watch(navTrackRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchChanges());
      final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
      return repository.getAll(diverId: diverId, ids: _ids(key));
    });
