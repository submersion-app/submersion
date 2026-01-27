import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';

/// Media for all dives in a trip, grouped by dive.
/// Returns a map of [Dive] to [MediaItem] list, preserving dive context.
final mediaForTripProvider =
    FutureProvider.family<Map<Dive, List<MediaItem>>, String>((
      ref,
      tripId,
    ) async {
      // Get all dives for this trip
      final dives = await ref.watch(divesForTripProvider(tripId).future);

      if (dives.isEmpty) {
        return {};
      }

      // Fetch media for each dive
      final Map<Dive, List<MediaItem>> result = {};

      for (final dive in dives) {
        final media = await ref.watch(mediaForDiveProvider(dive.id).future);
        if (media.isNotEmpty) {
          result[dive] = media;
        }
      }

      return result;
    });

/// Total media count for a trip (for badges/headers).
final mediaCountForTripProvider = FutureProvider.family<int, String>((
  ref,
  tripId,
) async {
  final mediaByDive = await ref.watch(mediaForTripProvider(tripId).future);
  return mediaByDive.values.fold<int>(0, (sum, list) => sum + list.length);
});

/// Flat list of all media for trip, sorted by takenAt.
/// Used for trip-scoped photo viewer navigation.
final flatMediaListForTripProvider =
    FutureProvider.family<List<MediaItem>, String>((ref, tripId) async {
      final mediaByDive = await ref.watch(mediaForTripProvider(tripId).future);

      final allMedia = mediaByDive.values.expand((list) => list).toList();

      // Sort by takenAt (chronological)
      allMedia.sort((a, b) => a.takenAt.compareTo(b.takenAt));

      return allMedia;
    });
