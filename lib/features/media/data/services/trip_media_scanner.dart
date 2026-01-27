import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';

/// Result of scanning the device gallery for trip photos.
///
/// Contains photos matched to specific dives, unmatched photos within the
/// trip date range, and a count of already linked photos that were filtered out.
class ScanResult {
  /// Photos matched to specific dives, keyed by dive.
  /// Each value is a list of [AssetInfo] objects from the device gallery.
  final Map<Dive, List<AssetInfo>> matchedByDive;

  /// Assets for photos within the trip date range but not matched to any dive.
  /// These may be surface interval shots, travel photos, etc.
  final List<AssetInfo> unmatched;

  /// Count of photos that were already linked and filtered out.
  final int alreadyLinkedCount;

  const ScanResult({
    required this.matchedByDive,
    required this.unmatched,
    required this.alreadyLinkedCount,
  });

  /// Total count of photos matched to dives.
  int get totalMatchedPhotos {
    int count = 0;
    for (final assets in matchedByDive.values) {
      count += assets.length;
    }
    return count;
  }

  /// Total count of new photos (matched + unmatched).
  int get totalNewPhotos => totalMatchedPhotos + unmatched.length;
}

/// Service for scanning the device photo gallery and matching photos to dives.
///
/// This service handles:
/// - Requesting photo library permissions
/// - Fetching photos within a trip date range
/// - Matching photos to dives based on timestamps
/// - Filtering out already linked photos
class TripMediaScanner {
  /// Default buffer time in minutes before/after dive boundaries.
  static const int defaultBufferMinutes = 30;

  /// Match a photo timestamp to a dive from a list of dives.
  ///
  /// Returns the dive if the photo was taken:
  /// - During the dive (between entry and exit time), or
  /// - Within [bufferMinutes] of the dive boundaries (before entry or after exit)
  ///
  /// If the photo matches multiple dives, returns the one with the closest
  /// time boundary. Exact matches (during dive) are preferred over buffer matches.
  ///
  /// Falls back to [Dive.dateTime] + [Dive.duration] if entry/exit times are not set.
  ///
  /// Returns null if no dive matches.
  static Dive? matchPhotoToDive(
    DateTime photoTime,
    List<Dive> dives, {
    int bufferMinutes = defaultBufferMinutes,
  }) {
    if (dives.isEmpty) {
      return null;
    }

    final bufferDuration = Duration(minutes: bufferMinutes);
    Dive? bestMatch;
    Duration? bestDistance;
    bool bestIsExact = false;

    for (final dive in dives) {
      final (entryTime, exitTime) = _getDiveBounds(dive);

      // Check if photo is during the dive (exact match)
      final isDuring =
          !photoTime.isBefore(entryTime) && !photoTime.isAfter(exitTime);

      if (isDuring) {
        // Calculate distance to nearest boundary for ranking
        final distanceToEntry = photoTime.difference(entryTime).abs();
        final distanceToExit = exitTime.difference(photoTime).abs();
        final distance = distanceToEntry < distanceToExit
            ? distanceToEntry
            : distanceToExit;

        if (bestMatch == null || !bestIsExact || distance < bestDistance!) {
          bestMatch = dive;
          bestDistance = distance;
          bestIsExact = true;
        }
        continue;
      }

      // If we already have an exact match, skip buffer checks
      if (bestIsExact) {
        continue;
      }

      // Check if photo is within buffer zone before entry
      final bufferedEntry = entryTime.subtract(bufferDuration);
      final isBeforeBuffer =
          !photoTime.isBefore(bufferedEntry) && photoTime.isBefore(entryTime);

      if (isBeforeBuffer) {
        final distance = entryTime.difference(photoTime);
        if (bestMatch == null || distance < bestDistance!) {
          bestMatch = dive;
          bestDistance = distance;
        }
        continue;
      }

      // Check if photo is within buffer zone after exit
      final bufferedExit = exitTime.add(bufferDuration);
      final isAfterBuffer =
          photoTime.isAfter(exitTime) && !photoTime.isAfter(bufferedExit);

      if (isAfterBuffer) {
        final distance = photoTime.difference(exitTime);
        if (bestMatch == null || distance < bestDistance!) {
          bestMatch = dive;
          bestDistance = distance;
        }
      }
    }

    return bestMatch;
  }

  /// Scan the device gallery for photos within a trip date range.
  ///
  /// [dives] - List of dives in the trip to match photos against.
  /// [tripStartDate] - Start of the trip (inclusive).
  /// [tripEndDate] - End of the trip (inclusive).
  /// [existingAssetIds] - Set of asset IDs already linked, to filter out.
  /// [photoPickerService] - Service for accessing the photo gallery.
  /// [bufferMinutes] - Buffer time around dive boundaries (default 30).
  ///
  /// Returns a [ScanResult] with matched and unmatched photos.
  /// Returns null if permission is denied.
  static Future<ScanResult?> scanGalleryForTrip({
    required List<Dive> dives,
    required DateTime tripStartDate,
    required DateTime tripEndDate,
    required Set<String> existingAssetIds,
    required PhotoPickerService photoPickerService,
    int bufferMinutes = defaultBufferMinutes,
  }) async {
    // Request permission
    final permission = await photoPickerService.requestPermission();
    if (permission != PhotoPermissionStatus.authorized &&
        permission != PhotoPermissionStatus.limited) {
      return null;
    }

    // Fetch photos within trip date range
    final assets = await photoPickerService.getAssetsInDateRange(
      tripStartDate,
      tripEndDate,
    );

    // Initialize result structures
    final Map<Dive, List<AssetInfo>> matchedByDive = {};
    final List<AssetInfo> unmatched = [];
    int alreadyLinkedCount = 0;

    for (final asset in assets) {
      // Skip already linked photos
      if (existingAssetIds.contains(asset.id)) {
        alreadyLinkedCount++;
        continue;
      }

      // Try to match to a dive
      final matchedDive = matchPhotoToDive(
        asset.createDateTime,
        dives,
        bufferMinutes: bufferMinutes,
      );

      if (matchedDive != null) {
        matchedByDive.putIfAbsent(matchedDive, () => []);
        matchedByDive[matchedDive]!.add(asset);
      } else {
        unmatched.add(asset);
      }
    }

    return ScanResult(
      matchedByDive: matchedByDive,
      unmatched: unmatched,
      alreadyLinkedCount: alreadyLinkedCount,
    );
  }

  /// Get the effective entry and exit times for a dive.
  ///
  /// Falls back to dateTime and dateTime + duration if entry/exit times not set.
  static (DateTime, DateTime) _getDiveBounds(Dive dive) {
    final entryTime = dive.entryTime ?? dive.dateTime;
    final exitTime =
        dive.exitTime ??
        (dive.duration != null
            ? dive.dateTime.add(dive.duration!)
            : dive.dateTime.add(const Duration(minutes: 60)));
    return (entryTime, exitTime);
  }
}
