import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip_story.dart';
import 'package:submersion/features/trips/domain/services/trip_story_builder.dart';
import 'package:submersion/features/trips/presentation/providers/liveaboard_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_media_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';

/// Site-history aggregates for planned-day context pills.
typedef SiteHistory = ({
  int diveCount,
  double? avgWaterTemp,
  double? avgMaxDepth,
});

/// Sightings for every dive in a trip, keyed by dive id (batched query).
///
/// [divesForTripProvider] does not hydrate `Dive.sightings`, so this provider
/// self-invalidates on sightings/species writes (same signal the per-dive
/// [diveSightingsProvider] uses) to keep the story's species badges fresh
/// after edits or sync.
final tripSightingsByDiveProvider =
    FutureProvider.family<Map<String, List<Sighting>>, String>((
      ref,
      tripId,
    ) async {
      ref.invalidateSelfWhen(
        ref.watch(diveRepositoryProvider).watchDiveDetailChanges(),
      );
      final diveIds = await ref.watch(diveIdsForTripProvider(tripId).future);
      if (diveIds.isEmpty) return {};
      final repository = ref.watch(speciesRepositoryProvider);
      return repository.getSightingsForDives(diveIds);
    });

/// The composed story for a trip. Watches all source providers so sync
/// invalidations cascade.
final tripStoryProvider = FutureProvider.family<TripStory, String>((
  ref,
  tripId,
) async {
  final trip = await ref.watch(tripByIdProvider(tripId).future);
  if (trip == null) {
    throw StateError('Trip not found: $tripId');
  }
  final dives = await ref.watch(divesForTripProvider(tripId).future);
  final itineraryDays = await ref.watch(itineraryDaysProvider(tripId).future);
  final checklistItems = await ref.watch(tripChecklistProvider(tripId).future);

  // Media and sightings are best-effort enrichments: read their current value
  // synchronously rather than awaiting (an errored provider future never
  // resolves, which would hang the Overview). While loading or on error this
  // yields empty, so the story renders without photo strips / species badges;
  // the watch re-composes the story once the source resolves or recovers.
  final mediaByDive =
      ref.watch(mediaForTripProvider(tripId)).asData?.value ??
      const <Dive, List<MediaItem>>{};
  final sightingsByDiveId =
      ref.watch(tripSightingsByDiveProvider(tripId)).asData?.value ??
      const <String, List<Sighting>>{};

  final mediaByDiveId = <String, List<MediaItem>>{
    for (final entry in mediaByDive.entries) entry.key.id: entry.value,
  };

  return buildTripStory(
    trip: trip,
    dives: dives,
    itineraryDays: itineraryDays,
    mediaByDiveId: mediaByDiveId,
    sightingsByDiveId: sightingsByDiveId,
    checklistItems: checklistItems,
    today: DateTime.now(),
  );
});

/// Diver history at a site, matched by name (for planned-day context pills).
/// Returns zero history when there is no active diver.
final siteHistoryByNameProvider = FutureProvider.autoDispose
    .family<SiteHistory, String>((ref, siteName) async {
      final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
      if (diverId == null) {
        return (diveCount: 0, avgWaterTemp: null, avgMaxDepth: null);
      }
      final repository = ref.watch(statisticsRepositoryProvider);
      return repository.getSiteHistoryByName(siteName, diverId: diverId);
    });
