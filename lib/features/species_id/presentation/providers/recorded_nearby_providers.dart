import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/services/media_location.dart';
import 'package:submersion/features/reef/domain/entities/nearby_species.dart';
import 'package:submersion/features/reef/domain/entities/reef_data_status.dart';
import 'package:submersion/features/reef/domain/services/reef_coordinate_key.dart';
import 'package:submersion/features/reef/presentation/providers/reef_providers.dart';
import 'package:submersion/features/species_id/data/services/nearby_list_gate.dart';
import 'package:submersion/features/species_id/domain/services/recorded_nearby.dart';
import 'package:submersion/features/species_id/presentation/providers/dive_species_run_providers.dart';

/// What a "Recorded nearby" list is read for: a dive, a photo's own
/// position, or both. A Species to review row passes no photo.
typedef NearbyListRequest = ({String? diveId, GeoPoint? photo});

/// [item]'s request: its dive, and its own GPS when it has both
/// coordinates, as naming reads a photo's position.
NearbyListRequest nearbyRequestForMedia(MediaItem item) =>
    (diveId: item.diveId, photo: mediaLocation(item));

/// The "Recorded nearby" list a marine life suggestion is checked against
/// (issue #4668): the site page's list for the place [nearbyListLocation]
/// picks. Null when there is no place, or the list is empty or cannot be
/// had, so a row shows no marker rather than waiting or saying why.
///
/// Read through [reefNearbySpeciesProvider], so every row at one place, and
/// the site page, share one search and one saved copy.
///
/// Never retried: GBIF's failures already arrive as an answer (unavailable),
/// so an error here is the logbook's, and asking again only holds a row
/// that shows nothing either way.
final recordedNearbyListProvider = FutureProvider.autoDispose
    .family<NearbySpecies?, NearbyListRequest>((ref, request) async {
      final diveId = request.diveId;
      ({bool exists, GeoPoint? site, GeoPoint? entry})? place;
      if (diveId != null) {
        // The place comes from the dive's row and its site's point.
        ref.invalidateSelfWhen(
          ref.read(diveRepositoryProvider).watchDivesChanges(),
        );
        ref.invalidateSelfWhen(
          ref.read(siteRepositoryProvider).watchSitesChanges(),
        );
        place = await ref.read(divePlaceRepositoryProvider).placeOf(diveId);
        if (!ref.mounted) return null;
      }
      // A dive that is gone has no site and no entry.
      final known = place != null && place.exists;
      final photo = request.photo;
      final point = nearbyListLocation(
        site: known ? place.site : null,
        // Photos a few metres apart read one list: the cache keeps one per
        // ~110 m cell anyway.
        photo: photo == null ? null : ReefCoordinateKey.quantize(photo),
        entry: known ? place.entry : null,
      );
      if (point == null) return null;
      final list = reefNearbySpeciesProvider(point);
      // Watched, not read: the subscription keeps the shared list alive for
      // the rows that join it later.
      Future<NearbySpecies?> watchList() async =>
          _shown(await ref.watch(list.future));
      // A list already here or on its way, for another row or the site
      // page, is read at once: the queue is only for asking GBIF.
      if (ref.exists(list)) return watchList();
      final turn = await ref.read(nearbyListGateProvider).acquire();
      // Its turn came after it left the screen: pass the turn on.
      if (!ref.mounted) {
        turn.release();
        return null;
      }
      // Another row started this list while it waited: join that fetch and
      // hand the turn straight on, since GBIF need not be asked again.
      if (ref.exists(list)) {
        turn.release();
        return watchList();
      }
      // Leaving while the list is on the way frees the turn at once.
      ref.onDispose(turn.release);
      try {
        return await watchList();
      } finally {
        turn.release();
      }
    }, retry: (_, _) => null);

/// The list a marker reads: only a complete or partial answer, never an
/// empty or failed one.
NearbySpecies? _shown(ReefPart<NearbySpecies> part) =>
    part.status == ReefDataStatus.ok ? part.value : null;

/// One gate for every marker, so a long Species to review page asks GBIF
/// for a few lists at a time rather than every one at once.
final nearbyListGateProvider = Provider<NearbyListGate>(
  (ref) => NearbyListGate(),
);
