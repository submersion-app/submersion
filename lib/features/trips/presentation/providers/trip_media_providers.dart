import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/trips/data/repositories/trip_media_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip_media_preview.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';

final tripMediaRepositoryProvider = Provider<TripMediaRepository>((ref) {
  return TripMediaRepository();
});

/// What the Overview and Photos previews show: each dive's earliest items and
/// the true counts, without loading the trip's gallery.
///
/// Re-read on a write to `media` and, through [diveIdsForTripProvider],
/// whenever the trip's dives change. A deleted dive clears its media's dive_id
/// by cascade without Drift seeing a write to `media`, so that second source
/// is load-bearing.
final tripMediaPreviewProvider =
    FutureProvider.family<TripMediaPreview, String>((ref, tripId) async {
      ref.invalidateSelfWhen(
        ref.watch(tripMediaRepositoryProvider).watchPreviewChanges(),
      );
      final diveIds = await ref.watch(diveIdsForTripProvider(tripId).future);
      if (diveIds.isEmpty) return TripMediaPreview.empty;
      final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
      return ref
          .watch(tripMediaRepositoryProvider)
          .getPreview(tripId, diverId: diverId);
    });

/// Every media item of a trip, grouped by dive, for the gallery and the
/// viewer. The whole gallery in memory, so it lives only while one of them is
/// open. Previews read [tripMediaPreviewProvider] instead.
final mediaForTripProvider = FutureProvider.autoDispose
    .family<Map<Dive, List<MediaItem>>, String>((ref, tripId) async {
      ref.invalidateSelfWhen(
        ref.watch(mediaRepositoryProvider).watchMediaChanges(),
      );
      final dives = await ref.watch(divesForTripProvider(tripId).future);
      if (dives.isEmpty) return {};
      final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
      final items = await ref
          .watch(tripMediaRepositoryProvider)
          .getMediaForTrip(tripId, diverId: diverId);

      final byDiveId = <String, List<MediaItem>>{};
      for (final item in items) {
        (byDiveId[item.diveId!] ??= []).add(item);
      }
      return {for (final dive in dives) dive: ?byDiveId[dive.id]};
    });

/// Total media count for a trip (for badges/headers).
final mediaCountForTripProvider = FutureProvider.family<int, String>((
  ref,
  tripId,
) async {
  final preview = await ref.watch(tripMediaPreviewProvider(tripId).future);
  return preview.mediaCount;
});

/// Flat list of all media for trip, sorted by takenAt.
/// Used for trip-scoped photo viewer navigation.
final flatMediaListForTripProvider = FutureProvider.autoDispose
    .family<List<MediaItem>, String>((ref, tripId) async {
      final mediaByDive = await ref.watch(mediaForTripProvider(tripId).future);

      final allMedia = mediaByDive.values.expand((list) => list).toList();

      allMedia.sort(compareMediaChronologically);

      return allMedia;
    });
