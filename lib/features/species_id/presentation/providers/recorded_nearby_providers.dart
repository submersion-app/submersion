import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/reef/domain/entities/nearby_species.dart';
import 'package:submersion/features/reef/domain/entities/reef_data_status.dart';
import 'package:submersion/features/reef/presentation/providers/reef_providers.dart';
import 'package:submersion/features/species_id/domain/services/recorded_nearby.dart';
import 'package:submersion/features/species_id/presentation/providers/dive_species_run_providers.dart';

/// What a "Recorded nearby" list is read for: a dive, a photo's own
/// position, or both. A Species to review row passes no photo.
typedef NearbyListRequest = ({String? diveId, GeoPoint? photo});

/// [item]'s request: its dive, and its own GPS when it has both
/// coordinates, as naming reads a photo's position.
NearbyListRequest nearbyRequestForMedia(MediaItem item) {
  final latitude = item.latitude;
  final longitude = item.longitude;
  return (
    diveId: item.diveId,
    photo: latitude != null && longitude != null
        ? GeoPoint(latitude, longitude)
        : null,
  );
}

/// The "Recorded nearby" list a marine life suggestion is checked against
/// (issue #4668): the site page's list for the place [nearbyListLocation]
/// picks. Null when there is no place, or the list is empty or cannot be
/// had, so a row shows no marker rather than waiting or saying why.
///
/// Read through [reefNearbySpeciesProvider], so every row at one place, and
/// the site page, share one search and one saved copy.
final recordedNearbyListProvider = FutureProvider.autoDispose
    .family<NearbySpecies?, NearbyListRequest>((ref, request) async {
      // The place comes from the dive's row and its site's point.
      ref.invalidateSelfWhen(
        ref.read(diveRepositoryProvider).watchDivesChanges(),
      );
      ref.invalidateSelfWhen(
        ref.read(siteRepositoryProvider).watchSitesChanges(),
      );
      final diveId = request.diveId;
      final place = diveId == null
          ? null
          : await ref.read(divePlaceRepositoryProvider).placeOf(diveId);
      if (!ref.mounted) return null;
      // A dive that is gone has no site and no entry.
      final known = place != null && place.exists;
      final point = nearbyListLocation(
        site: known ? place.site : null,
        photo: request.photo,
        entry: known ? place.entry : null,
      );
      if (point == null) return null;
      final part = await ref.watch(reefNearbySpeciesProvider(point).future);
      return part.status == ReefDataStatus.ok ? part.value : null;
    });
