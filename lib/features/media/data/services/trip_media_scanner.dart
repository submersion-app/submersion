import 'dart:io';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/data/services/exif_extractor.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/domain/services/dive_photo_matcher.dart';
import 'package:submersion/features/media/domain/value_objects/extracted_file.dart';
import 'package:submersion/features/media/domain/value_objects/matched_selection.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';

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
/// - Matching photos to dives based on timestamps (via [DivePhotoMatcher])
/// - Filtering out already linked photos
///
/// Time convention: Dive times use wall-clock-as-UTC (e.g. a 10:00 AM local
/// dive is stored as DateTime.utc(_, _, _, 10, 0)). Photo times from the
/// device gallery are local DateTimes. All comparisons normalise both sides
/// to wall-clock-as-UTC so that only the displayed hour/minute matter, not
/// the underlying epoch.
class TripMediaScanner {
  static final _log = LoggerService.forClass(TripMediaScanner);

  static const Duration _photoLibraryTimezoneSlack = Duration(days: 1);
  static final Set<Duration> _fallbackTimezoneOffsets = {
    for (var hours = -12; hours <= 14; hours += 1) Duration(hours: hours),
  };

  /// Default pre-dive buffer time in minutes (mirrors [DivePhotoMatcher.preBuffer]).
  static const int defaultPreBufferMinutes = 30;

  /// Default post-dive buffer time in minutes (mirrors [DivePhotoMatcher.postBuffer]).
  static const int defaultPostBufferMinutes = 60;

  /// Default buffer time in minutes before dive boundaries.
  ///
  /// Kept for API compatibility. For matching, the post-dive buffer is wider
  /// (60 min) — see [defaultPostBufferMinutes].
  static const int defaultBufferMinutes = defaultPreBufferMinutes;

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
  @Deprecated(
    'Use DivePhotoMatcher.match() instead. This static helper is retained '
    'only for legacy test coverage; its symmetric 30-minute buffer differs '
    'from DivePhotoMatcher\'s asymmetric 30 pre / 60 post (per spec).',
  )
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
  ///
  /// Matching is delegated to [DivePhotoMatcher], which applies a 30-minute
  /// pre-dive buffer and a 60-minute post-dive buffer.
  ///
  /// Returns a [ScanResult] with matched and unmatched photos.
  /// Returns null if permission is denied.
  static Future<ScanResult?> scanGalleryForTrip({
    required List<Dive> dives,
    required DateTime tripStartDate,
    required DateTime tripEndDate,
    required Set<String> existingAssetIds,
    required PhotoPickerService photoPickerService,
    Future<MediaSourceMetadata?> Function(AssetInfo asset)?
    assetMetadataResolver,
  }) async {
    // Request permission
    final permission = await photoPickerService.requestPermission();
    if (permission != PhotoPermissionStatus.authorized &&
        permission != PhotoPermissionStatus.limited) {
      return null;
    }

    // Trip dates are date-only values. Query the full selected calendar days
    // so photos taken later on the trip's final day are not excluded.
    //
    // Convert from wall-clock-as-UTC to local for photo_manager, which filters
    // by local device time.
    final tripWindowStart = toWallClockUtc(_startOfDay(tripStartDate));
    final tripWindowEnd = toWallClockUtc(_endOfDay(tripEndDate));
    final queryStart = wallClockUtcToLocal(
      tripWindowStart.subtract(_photoLibraryTimezoneSlack),
    );
    final queryEnd = wallClockUtcToLocal(
      tripWindowEnd.add(_photoLibraryTimezoneSlack),
    );

    final assets = await photoPickerService.getAssetsInDateRange(
      queryStart,
      queryEnd,
    );

    // Build lookup and ExtractedFile list for the matcher.
    final assetById = {for (final a in assets) a.id: a};
    final newAssets = assets
        .where((a) => !existingAssetIds.contains(a.id))
        .toList();
    final primaryExtractedById = <String, ExtractedFile>{};
    for (final asset in newAssets) {
      final extracted = _toExtractedFile(asset);
      final takenAt = extracted.metadata.takenAt;
      if (takenAt != null &&
          _isInRange(takenAt, tripWindowStart, tripWindowEnd)) {
        primaryExtractedById[asset.id] = extracted;
      }
    }

    // Build DiveBounds from each dive (normalised to wall-clock-as-UTC).
    final bounds = dives.map((dive) {
      final (rawEntry, rawExit) = _getDiveBounds(dive);
      return DiveBounds(
        diveId: dive.id,
        entryTime: toWallClockUtc(rawEntry),
        exitTime: toWallClockUtc(rawExit),
      );
    }).toList();

    final matcher = DivePhotoMatcher();
    final primarySelection = matcher.match(
      files: primaryExtractedById.values.toList(),
      dives: bounds,
    );

    final primaryMatchedAssetIds = _matchedAssetIds(primarySelection);
    final locationTimezoneOffsets = _likelyTripTimezoneOffsets(dives);
    final timezoneOffsets = locationTimezoneOffsets.isEmpty
        ? _fallbackTimezoneOffsets
        : locationTimezoneOffsets;
    final fallbackCandidates = newAssets
        .where((asset) => !primaryMatchedAssetIds.contains(asset.id))
        .where(
          (asset) => _couldMatchWithTimezoneShift(
            asset.createDateTime,
            bounds,
            timezoneOffsets,
          ),
        )
        .toList();
    final fallbackExtractedById = await _loadExifFallbacks(
      assets: fallbackCandidates,
      tripWindowStart: tripWindowStart,
      tripWindowEnd: tripWindowEnd,
      assetMetadataResolver:
          assetMetadataResolver ??
          (asset) => _extractAssetFileMetadata(asset, photoPickerService),
    );
    final fallbackSelection = matcher.match(
      files: fallbackExtractedById.values.toList(),
      dives: bounds,
    );

    final selection = _mergeSelections(
      primarySelection: primarySelection,
      fallbackSelection: fallbackSelection,
    );
    _log.debug(
      'Trip media scan assets=${assets.length} new=${newAssets.length} '
      'primary=${primaryExtractedById.length} '
      'exifFallback=${fallbackExtractedById.length} '
      'matched=${selection.matched.values.fold<int>(0, (sum, files) => sum + files.length)} '
      'unmatched=${selection.unmatched.length}',
    );

    // Round-trip matched files back to AssetInfo via sourcePath == asset.id.
    final diveById = {for (final d in dives) d.id: d};
    final Map<Dive, List<AssetInfo>> matchedByDive = {};
    for (final entry in selection.matched.entries) {
      final dive = diveById[entry.key];
      if (dive == null) continue;
      matchedByDive[dive] = entry.value
          .map((ef) => assetById[ef.sourcePath]!)
          .toList();
    }

    final List<AssetInfo> unmatched = selection.unmatched
        .map((ef) => assetById[ef.sourcePath]!)
        .toList();

    final alreadyLinkedCount =
        assets.length - newAssets.length; // already filtered before matching

    return ScanResult(
      matchedByDive: matchedByDive,
      unmatched: unmatched,
      alreadyLinkedCount: alreadyLinkedCount,
    );
  }

  /// Scan the device gallery for photos near a single dive.
  ///
  /// Uses the dive's entry/exit times with [DivePhotoMatcher.preBuffer] before
  /// entry and [DivePhotoMatcher.postBuffer] after exit as the gallery query
  /// window. Filters out photos whose asset IDs are in [existingAssetIds].
  ///
  /// Returns a list of new [AssetInfo] found, or null if permission is denied.
  static Future<List<AssetInfo>?> scanGalleryForDive({
    required Dive dive,
    required Set<String> existingAssetIds,
    required PhotoPickerService photoPickerService,
  }) async {
    final permission = await photoPickerService.requestPermission();
    if (permission != PhotoPermissionStatus.authorized &&
        permission != PhotoPermissionStatus.limited) {
      return null;
    }

    final (entryTime, exitTime) = _getDiveBounds(dive);
    final rangeStart = entryTime.subtract(DivePhotoMatcher.preBuffer);
    final rangeEnd = exitTime.add(DivePhotoMatcher.postBuffer);

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
      dt.microsecond,
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
      dt.microsecond,
    );
  }

  static DateTime _startOfDay(DateTime dt) => dt.isUtc
      ? DateTime.utc(dt.year, dt.month, dt.day)
      : DateTime(dt.year, dt.month, dt.day);

  static DateTime _endOfDay(DateTime dt) {
    final nextDay = dt.isUtc
        ? DateTime.utc(dt.year, dt.month, dt.day + 1)
        : DateTime(dt.year, dt.month, dt.day + 1);
    return nextDay.subtract(const Duration(microseconds: 1));
  }

  static bool _isInRange(DateTime value, DateTime start, DateTime end) =>
      !value.isBefore(start) && !value.isAfter(end);

  static bool _couldMatchWithTimezoneShift(
    DateTime assetTime,
    List<DiveBounds> bounds,
    Set<Duration> likelyTimezoneOffsets,
  ) {
    if (likelyTimezoneOffsets.isEmpty) {
      return false;
    }

    for (final tripOffset in likelyTimezoneOffsets) {
      final shiftedAssetTime = toWallClockUtc(
        assetTime.add(tripOffset - assetTime.timeZoneOffset),
      );
      for (final dive in bounds) {
        final earliest = dive.entryTime.subtract(DivePhotoMatcher.preBuffer);
        final latest = dive.exitTime.add(DivePhotoMatcher.postBuffer);
        if (_isInRange(shiftedAssetTime, earliest, latest)) {
          return true;
        }
      }
    }
    return false;
  }

  static Set<Duration> _likelyTripTimezoneOffsets(List<Dive> dives) {
    final offsets = <Duration>{};
    for (final dive in dives) {
      final longitude =
          dive.entryLocation?.longitude ??
          dive.exitLocation?.longitude ??
          dive.site?.location?.longitude;
      if (longitude == null) continue;
      final hours = (longitude / 15).round().clamp(-12, 14);
      offsets.add(Duration(hours: hours));
    }
    return offsets;
  }

  static Set<String> _matchedAssetIds(MatchedSelection selection) => selection
      .matched
      .values
      .expand((files) => files)
      .map((file) => file.sourcePath)
      .toSet();

  static Future<Map<String, ExtractedFile>> _loadExifFallbacks({
    required List<AssetInfo> assets,
    required DateTime tripWindowStart,
    required DateTime tripWindowEnd,
    required Future<MediaSourceMetadata?> Function(AssetInfo asset)
    assetMetadataResolver,
  }) async {
    final extractedById = <String, ExtractedFile>{};
    for (final asset in assets) {
      final metadata = await assetMetadataResolver(asset);
      final takenAt = metadata?.takenAt;
      if (metadata == null ||
          takenAt == null ||
          !_isInRange(takenAt, tripWindowStart, tripWindowEnd)) {
        continue;
      }
      extractedById[asset.id] = ExtractedFile(
        sourcePath: asset.id,
        file: File(asset.id),
        metadata: MediaSourceMetadata(
          takenAt: takenAt,
          latitude: metadata.latitude ?? asset.latitude,
          longitude: metadata.longitude ?? asset.longitude,
          width: metadata.width ?? asset.width,
          height: metadata.height ?? asset.height,
          durationSeconds: metadata.durationSeconds ?? asset.durationSeconds,
          mimeType: metadata.mimeType,
        ),
      );
    }
    return extractedById;
  }

  static Future<MediaSourceMetadata?> _extractAssetFileMetadata(
    AssetInfo asset,
    PhotoPickerService photoPickerService,
  ) async {
    try {
      final nativeMetadata = await photoPickerService.getAssetMetadata(
        asset.id,
      );
      if (nativeMetadata?.takenAt != null) {
        return nativeMetadata;
      }

      final path = await photoPickerService.getFilePath(asset.id);
      if (path == null) return null;
      return ExifExtractor().extract(File(path));
    } on Object catch (error, stackTrace) {
      _log.debug(
        'Failed to extract EXIF fallback for gallery asset ${asset.id}',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  static MatchedSelection _mergeSelections({
    required MatchedSelection primarySelection,
    required MatchedSelection fallbackSelection,
  }) {
    final fallbackMatchedAssetIds = _matchedAssetIds(fallbackSelection);
    final matched = <String, List<ExtractedFile>>{};
    for (final entry in primarySelection.matched.entries) {
      matched[entry.key] = [...entry.value];
    }
    for (final entry in fallbackSelection.matched.entries) {
      matched.putIfAbsent(entry.key, () => []).addAll(entry.value);
    }

    final unmatchedById = <String, ExtractedFile>{};
    for (final file in primarySelection.unmatched) {
      if (!fallbackMatchedAssetIds.contains(file.sourcePath)) {
        unmatchedById[file.sourcePath] = file;
      }
    }
    for (final file in fallbackSelection.unmatched) {
      unmatchedById.putIfAbsent(file.sourcePath, () => file);
    }

    return MatchedSelection(
      matched: matched,
      unmatched: unmatchedById.values.toList(),
    );
  }

  /// Convert an [AssetInfo] to an [ExtractedFile] for use with [DivePhotoMatcher].
  ///
  /// The [sourcePath] is set to [AssetInfo.id] so that the round-trip lookup
  /// works via [assetById]. The [File] handle is synthetic and not read by
  /// the matcher (only [metadata.takenAt] is consumed). The [createDateTime]
  /// is normalised to wall-clock-as-UTC so it compares correctly against dive
  /// times stored in the same convention.
  static ExtractedFile _toExtractedFile(AssetInfo asset) => ExtractedFile(
    sourcePath: asset.id,
    file: File(asset.id),
    metadata: MediaSourceMetadata(
      takenAt: toWallClockUtc(asset.createDateTime),
      latitude: asset.latitude,
      longitude: asset.longitude,
      width: asset.width,
      height: asset.height,
      durationSeconds: asset.durationSeconds,
      mimeType: 'image/jpeg',
    ),
  );
}
