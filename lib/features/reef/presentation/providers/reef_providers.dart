import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:http/http.dart' as http;

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/reef/data/repositories/reef_cache_dao.dart';
import 'package:submersion/features/reef/data/repositories/reef_repository.dart';
import 'package:submersion/features/reef/data/services/nearby_species_service.dart';
import 'package:submersion/features/reef/data/services/reef_habitat_service.dart';
import 'package:submersion/features/reef/data/services/reef_health_service.dart';
import 'package:submersion/features/reef/data/services/reef_protection_service.dart';
import 'package:submersion/features/reef/domain/entities/nearby_species.dart';
import 'package:submersion/features/reef/domain/entities/reef_data_status.dart';
import 'package:submersion/features/reef/domain/entities/reef_habitat.dart';
import 'package:submersion/features/reef/domain/entities/reef_health.dart';
import 'package:submersion/features/reef/domain/entities/reef_protection.dart';

/// Shared HTTP client. Overridden in tests with a MockClient.
final reefHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final reefRepositoryProvider = Provider<ReefRepository>((ref) {
  final client = ref.watch(reefHttpClientProvider);
  return ReefRepository(
    cache: ReefCacheDao(LocalCacheDatabaseService.instance.database),
    habitat: ReefHabitatService(client: client),
    health: ReefHealthService(client: client),
    protection: ReefProtectionService(client: client),
    species: NearbySpeciesService(client: client),
  );
});

/// Reef presence and threat level, for the site's Ecosystem section and the
/// dive detail page's water-conditions card.
// no-tick: reef data comes from REMOTE services (habitat, health, protection,
// nearby species) cached aside by quantized coordinate. Nothing the app writes
// can change it, so there is no table to subscribe to.
final reefHabitatProvider =
    FutureProvider.family<ReefPart<ReefHabitat>, GeoPoint>((ref, location) {
      return ref.watch(reefRepositoryProvider).habitatFor(location);
    });

/// Current water conditions. Freshwater sites must not watch this: NOAA's
/// grid covers only oceans.
// no-tick: remote reef data keyed by quantized coordinate, as above.
final reefCurrentHealthProvider =
    FutureProvider.family<ReefPart<ReefHealth>, GeoPoint>((ref, location) {
      return ref.watch(reefRepositoryProvider).currentHealthFor(location);
    });

/// Marine protected areas containing a location.
// no-tick: remote reef data keyed by quantized coordinate, as above.
final reefProtectionProvider =
    FutureProvider.family<ReefPart<List<ReefProtection>>, GeoPoint>((
      ref,
      location,
    ) {
      return ref.watch(reefRepositoryProvider).protectionFor(location);
    });

/// Species recorded near a location.
///
/// This part has no retry button, so only a complete answer is held for the
/// session. A failed one goes with its last watcher, and its cached failure
/// spaces out the next try. A partial one has no cache row to do that, so it
/// is held for the same window: otherwise every visit would resend the search
/// and every name lookup, perhaps to a server already rate limiting them.
// no-tick: remote reef data keyed by quantized coordinate, as above.
final reefNearbySpeciesProvider = FutureProvider.autoDispose
    .family<ReefPart<NearbySpecies>, GeoPoint>((ref, location) async {
      final part = await ref.watch(reefRepositoryProvider).speciesFor(location);
      if (!ref.mounted || part.status == ReefDataStatus.unavailable) {
        return part;
      }
      final hold = ref.keepAlive();
      if (part.value?.namesIncomplete == true) {
        final expiry = Timer(ReefCacheDao.failureTtl, hold.close);
        ref.onDispose(expiry.cancel);
      }
      return part;
    });

/// Identifies a historical reef-health lookup for one dive.
///
/// Equality deliberately compares only the UTC calendar date: NOAA publishes
/// one observation per day, so two dives on the same day share a result.
class ReefHealthRequest extends Equatable {
  final GeoPoint location;
  final DateTime date;

  const ReefHealthRequest({required this.location, required this.date});

  @override
  List<Object?> get props => [
    location,
    date.toUtc().year,
    date.toUtc().month,
    date.toUtc().day,
  ];
}

/// Reef health as it was on a dive's date.
// no-tick: remote reef data keyed by quantized coordinate and date, as above.
final reefHealthForDiveProvider =
    FutureProvider.family<ReefPart<ReefHealth>, ReefHealthRequest>((
      ref,
      request,
    ) {
      return ref
          .watch(reefRepositoryProvider)
          .healthFor(request.location, request.date);
    });
