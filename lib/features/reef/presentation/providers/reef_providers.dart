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
import 'package:submersion/features/reef/domain/entities/reef_data_status.dart';
import 'package:submersion/features/reef/domain/entities/reef_health.dart';
import 'package:submersion/features/reef/domain/entities/reef_snapshot.dart';

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

/// All four reef-data parts for a location. Fetched when a site is viewed.
final reefSnapshotProvider = FutureProvider.family<ReefSnapshot, GeoPoint>((
  ref,
  location,
) {
  return ref.watch(reefRepositoryProvider).snapshotFor(location);
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
final reefHealthForDiveProvider =
    FutureProvider.family<ReefPart<ReefHealth>, ReefHealthRequest>((
      ref,
      request,
    ) {
      return ref
          .watch(reefRepositoryProvider)
          .healthFor(request.location, request.date);
    });
