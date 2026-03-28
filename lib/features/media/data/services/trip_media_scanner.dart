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
///
/// Time convention: Dive times use wall-clock-as-UTC (e.g. a 10:00 AM local
/// dive is stored as DateTime.utc(_, _, _, 10, 0)). Photo times from the
/// device gallery are local DateTimes. All comparisons normalise both sides
/// to wall-clock-as-UTC so that only the displayed hour/minute matter, not
/// the underlying epoch.
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

    // Normalise photo time to wall-clock-as-UTC so epoch comparisons
    // work correctly against dive times (which are wall-clock-as-UTC).
    final normalizedPhotoTime = toWallClockUtc(photoTime);

    final bufferDuration = Duration(minutes: bufferMinutes);
    Dive? bestMatch;
    Duration? bestDistance;
    bool bestIsExact = false;

    for (final dive in dives) {
      final (rawEntry, rawExit) = _getDiveBounds(dive);
      final entryTime = toWallClockUtc(rawEntry);
      final exitTime = toWallClockUtc(rawExit);

      // Check if photo is during the dive (exact match)
      final isDuring =
          !normalizedPhotoTime.isBefore(entryTime) &&
          !normalizedPhotoTime.isAfter(exitTime);

      if (isDuring) {
        // Calculate distance to nearest boundary for ranking
        final distanceToEntry = normalizedPhotoTime.difference(entryTime).abs();
        final distanceToExit = exitTime.difference(normalizedPhotoTime).abs();
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
          !normalizedPhotoTime.isBefore(bufferedEntry) &&
          normalizedPhotoTime.isBefore(entryTime);

      if (isBeforeBuffer) {
        final distance = entryTime.difference(normalizedPhotoTime);
        if (bestMatch == null || distance < bestDistance!) {
          bestMatch = dive;
          bestDistance = distance;
        }
        continue;
      }

      // Check if photo is within buffer zone after exit
      final bufferedExit = exitTime.add(bufferDuration);
      final isAfterBuffer =
          normalizedPhotoTime.isAfter(exitTime) &&
          !normalizedPhotoTime.isAfter(bufferedExit);

      if (isAfterBuffer) {
        final distance = normalizedPhotoTime.difference(exitTime);
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

    // Convert trip dates from wall-clock-as-UTC to local for photo_manager,
    // which filters by local device time.
    final assets = await photoPickerService.getAssetsInDateRange(
      wallClockUtcToLocal(tripStartDate),
      wallClockUtcToLocal(tripEndDate),
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

  /// Scan the device gallery for photos near a single dive.
  ///
  /// Uses the dive's entry/exit times with a [bufferMinutes] window on each
  /// side. Filters out photos whose asset IDs are in [existingAssetIds].
  ///
  /// Returns a list of new [AssetInfo] found, or null if permission is denied.
  static Future<List<AssetInfo>?> scanGalleryForDive({
    required Dive dive,
    required Set<String> existingAssetIds,
    required PhotoPickerService photoPickerService,
    int bufferMinutes = defaultBufferMinutes,
  }) async {
    final permission = await photoPickerService.requestPermission();
    if (permission != PhotoPermissionStatus.authorized &&
        permission != PhotoPermissionStatus.limited) {
      return null;
    }

    final (entryTime, exitTime) = _getDiveBounds(dive);
    final bufferDuration = Duration(minutes: bufferMinutes);
    final rangeStart = entryTime.subtract(bufferDuration);
    final rangeEnd = exitTime.add(bufferDuration);

    // Convert from wall-clock-as-UTC to local for photo_manager,
    // which filters by local device time.
    final assets = await photoPickerService.getAssetsInDateRange(
      wallClockUtcToLocal(rangeStart),
      wallClockUtcToLocal(rangeEnd),
    );

    return assets
        .where((asset) => !existingAssetIds.contains(asset.id))
        .toList();
  }

  /// Get the effective entry and exit times for a dive.
  ///
  /// Falls back to dateTime and dateTime + duration if entry/exit times not set.
  static (DateTime, DateTime) _getDiveBounds(Dive dive) {
    final entryTime = dive.entryTime ?? dive.dateTime;
    final exitTime =
        dive.exitTime ??
        (dive.effectiveRuntime != null
            ? dive.dateTime.add(dive.effectiveRuntime!)
            : dive.dateTime.add(const Duration(minutes: 60)));
    return (entryTime, exitTime);
  }

  /// Convert a local [DateTime] to wall-clock-as-UTC by preserving the
  /// year/month/day/hour/minute/second components and setting isUtc = true.
  ///
  /// If the value is already UTC it is returned unchanged.
  /// This is used to normalise photo timestamps (local) so they can be
  /// compared against dive times (wall-clock-as-UTC).
  static DateTime toWallClockUtc(DateTime dt) {
    if (dt.isUtc) return dt;
    return DateTime.utc(
      dt.year,
      dt.month,
      dt.day,
      dt.hour,
      dt.minute,
      dt.second,
      dt.millisecond,
    );
  }

  /// Convert a wall-clock-as-UTC [DateTime] to a local [DateTime] by
  /// preserving the year/month/day/hour/minute/second components.
  ///
  /// If the value is already local it is returned unchanged.
  /// This is used when passing dive time bounds to the photo gallery API,
  /// which expects local DateTimes.
  static DateTime wallClockUtcToLocal(DateTime dt) {
    if (!dt.isUtc) return dt;
    return DateTime(
      dt.year,
      dt.month,
      dt.day,
      dt.hour,
      dt.minute,
      dt.second,
      dt.millisecond,
    );
  }
}
