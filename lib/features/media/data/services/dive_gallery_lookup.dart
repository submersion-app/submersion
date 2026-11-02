import 'dart:async';
import 'dart:io';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/util/wall_clock_utc.dart';
import 'package:submersion/features/media/data/services/exif_extractor.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';
import 'package:submersion/features/media/domain/value_objects/taken_at_source.dart';

/// The most two clocks on Earth can disagree: UTC+14 against UTC-12.
const Duration _widestZoneGap = Duration(hours: 26);

/// Two times this close are the same clock reading. Zone offsets start at 15
/// minutes, and the seconds of a re-saved file's date can drift.
const Duration _sameClockTolerance = Duration(minutes: 1);

/// How many dated photos inside the dive window must agree with the device
/// before it is believed. They are likely one camera, so one speaks for them.
const int _clockSamplesInside = 1;

/// How many dated photos outside the dive window must agree. These are what
/// a wrong clock has pushed away, so they are the evidence that counts.
const int _clockSamplesOutside = 3;

/// How many photos the clock check may read in all, dated or not. A library
/// short on EXIF should not be fetched whole to find the samples above.
const int _clockSampleReads = 8;

/// How long one photo's metadata may take. A photo held only in iCloud has to
/// download, and on a dive boat that can stall for good.
const Duration _readTimeout = Duration(seconds: 15);

/// How long one search may spend reading before it settles for what it has.
/// The picker shows nothing until the search returns.
const Duration _readBudget = Duration(seconds: 60);

final _log = LoggerService.forClass(DiveGalleryLookup);

/// Finds the gallery photos taken during one dive (issue #259).
///
/// Dives and photos are matched wall-time to wall-time, but a photo library
/// has no wall-time to give: `AssetInfo.createDateTime` is a moment in time
/// read back on this device's clock. Those digits only equal what the diver's
/// clock showed while the device is in the zone the photo was taken in. Once
/// it has moved, every photo of the trip sits hours outside the dive window,
/// so the search asks for every zone the device could be in and judges the
/// results by each photo's EXIF `DateTimeOriginal`, which is the wall-time.
///
/// A photo's EXIF can mean downloading it from iCloud, so a few photos are
/// sampled first: while they agree with the device's clock, which is nearly
/// always, nothing else is fetched. The sample reaches outside the window
/// because a photo inside it cannot speak for the rest: a camera that records
/// no timezone agrees with the device however far the phone has travelled,
/// while the phone's own photos of the same dive sit hours away.
///
/// A library that disagrees only beyond the nearest photos is not noticed.
/// Reading everything to rule that out would download two days of photos
/// each time the picker opens, for every diver.
///
/// EXIF only ever adds a photo or corrects its time. A photo this device
/// already places in the dive stays even when its EXIF says otherwise, because
/// a date corrected in Photos leaves the EXIF stale: the device is right then.
abstract final class DiveGalleryLookup {
  /// The library's photos and videos from `[windowStart, windowEnd]`, a dive
  /// window in wall-clock-as-UTC, newest first.
  ///
  /// A photo found through its EXIF comes back with `createDateTime` set to
  /// that wall-time, so what is imported from it stores the time the diver
  /// saw, and lands in the right place on the profile.
  ///
  /// [isActive] is asked before each read, so a caller that has gone away
  /// stops the fetching. What had been found by then is returned, as it is
  /// when the reads run out of time.
  static Future<List<AssetInfo>> find({
    required DateTime windowStart,
    required DateTime windowEnd,
    required PhotoPickerService photoPickerService,
    bool Function()? isActive,
  }) async {
    final start = asWallClockUtc(windowStart);
    final end = asWallClockUtc(windowEnd);

    // Windows and Linux have no library to search: this call is a file
    // dialog, and what the diver picks in it is the answer.
    if (!photoPickerService.supportsGalleryBrowsing) {
      return photoPickerService.getAssetsInDateRange(
        fromWallClockUtc(start),
        fromWallClockUtc(end),
      );
    }

    final assets = await photoPickerService.getAssetsInDateRange(
      fromWallClockUtc(start.subtract(_widestZoneGap)),
      fromWallClockUtc(end.add(_widestZoneGap)),
    );

    bool inWindow(DateTime wallTime) =>
        !wallTime.isBefore(start) && !wallTime.isAfter(end);
    final found = {
      for (final asset in assets)
        if (inWindow(asWallClockUtc(asset.createDateTime))) asset.id: asset,
    };

    // A video's only date is a header some cameras write in UTC and others
    // in local time, and reading it means fetching the whole video.
    final photos = assets.where((a) => !a.isVideo).toList()
      ..sort(
        (a, b) =>
            _gapToWindow(a, start, end).compareTo(_gapToWindow(b, start, end)),
      );

    final wallTimes = <String, DateTime?>{};
    Future<DateTime?> wallTimeOf(AssetInfo photo) async {
      if (wallTimes.containsKey(photo.id)) return wallTimes[photo.id];
      return wallTimes[photo.id] = await _captureWallTime(
        photo,
        photoPickerService,
      );
    }

    var outOfTime = false;
    final readBudget = Timer(_readBudget, () => outOfTime = true);
    bool stillWanted() => !outOfTime && (isActive == null || isActive());

    try {
      var insideLeft = _clockSamplesInside;
      var outsideLeft = _clockSamplesOutside;
      var readsLeft = _clockSampleReads;
      Duration? clockGap;
      for (final photo in photos) {
        if (readsLeft == 0 || insideLeft + outsideLeft == 0) break;
        final inside = found.containsKey(photo.id);
        if ((inside ? insideLeft : outsideLeft) == 0) continue;
        if (!stillWanted()) break;
        readsLeft--;
        final wallTime = await wallTimeOf(photo);
        if (wallTime == null) continue;

        final gap = wallTime.difference(asWallClockUtc(photo.createDateTime));
        // No timezone is this far out: the camera's own clock was wrong.
        if (gap.abs() > _widestZoneGap) continue;
        if (gap.abs() >= _sameClockTolerance) {
          clockGap = gap;
          break;
        }
        if (inside) {
          insideLeft--;
        } else {
          outsideLeft--;
        }
      }

      if (clockGap case final gap?) {
        // Photos from the same clock are out by the same gap, so the dive's
        // own photos come first in case the time runs out.
        final likeliestFirst = [...photos]
          ..sort(
            (a, b) => _gapToWindow(
              a,
              start,
              end,
              shift: gap,
            ).compareTo(_gapToWindow(b, start, end, shift: gap)),
          );
        for (final photo in likeliestFirst) {
          if (!stillWanted()) break;
          final wallTime = await wallTimeOf(photo);
          if (wallTime != null && inWindow(wallTime)) {
            found[photo.id] = photo.copyWith(
              createDateTime: fromWallClockUtc(wallTime),
            );
          }
        }
      }
    } finally {
      readBudget.cancel();
    }

    return found.values.toList()
      ..sort((a, b) => b.createDateTime.compareTo(a.createDateTime));
  }

  /// [assets] the diver assigned to a dive by hand, each carrying the time to
  /// store with it. [windowStart] and [windowEnd] are that dive's window in
  /// wall-clock-as-UTC.
  ///
  /// A review can pair a photo with a dive its device digits never reached,
  /// so a photo that has moved zones gets its EXIF wall-time here. The same
  /// rule as [find] applies: EXIF must land in the dive to count. A photo the
  /// device already places in the dive costs no read, so the usual import
  /// downloads nothing, and one still unread when time runs out keeps the
  /// device's digits.
  static Future<List<AssetInfo>> correctedForDive({
    required List<AssetInfo> assets,
    required DateTime windowStart,
    required DateTime windowEnd,
    required PhotoPickerService photoPickerService,
  }) async {
    // A file dialog's time came from the file itself.
    if (!photoPickerService.supportsGalleryBrowsing) return assets;

    final start = asWallClockUtc(windowStart);
    final end = asWallClockUtc(windowEnd);

    var outOfTime = false;
    final readBudget = Timer(_readBudget, () => outOfTime = true);
    try {
      final corrected = <AssetInfo>[];
      for (final asset in assets) {
        final worthReading =
            !outOfTime &&
            !asset.isVideo &&
            _gapToWindow(asset, start, end) > Duration.zero;
        final wallTime = worthReading
            ? await _captureWallTime(asset, photoPickerService)
            : null;
        corrected.add(
          wallTime != null &&
                  !wallTime.isBefore(start) &&
                  !wallTime.isAfter(end)
              ? asset.copyWith(createDateTime: fromWallClockUtc(wallTime))
              : asset,
        );
      }
      return corrected;
    } finally {
      readBudget.cancel();
    }
  }

  /// How far [asset]'s digits on this device, moved by [shift], are from the
  /// window; zero inside it. The nearest photo is the likeliest to be from
  /// the same trip.
  static Duration _gapToWindow(
    AssetInfo asset,
    DateTime start,
    DateTime end, {
    Duration shift = Duration.zero,
  }) {
    final digits = asWallClockUtc(asset.createDateTime).add(shift);
    if (digits.isBefore(start)) return start.difference(digits);
    if (digits.isAfter(end)) return digits.difference(end);
    return Duration.zero;
  }

  /// The wall-time [asset]'s own metadata records, or null when it has none.
  ///
  /// A file's modified date does not count: it is when the file was copied
  /// or edited, and this read's copy of the file was made moments ago.
  static Future<DateTime?> _captureWallTime(
    AssetInfo asset,
    PhotoPickerService photoPickerService,
  ) async {
    final metadata = await readGalleryAssetMetadata(asset, photoPickerService);
    if (metadata == null ||
        metadata.takenAtSource == TakenAtSource.fileModifiedTime) {
      return null;
    }
    return metadata.takenAt;
  }
}

/// [asset]'s original metadata: from the platform's photo library when it can
/// answer, otherwise from a copy of the file.
///
/// The copy is a last resort for a platform with no native reader. On iOS it
/// is a JPEG photo_manager rendered without the original's EXIF, so a native
/// answer for a photo stands even when it found no capture time. A video
/// falls through because native readers only date photos.
///
/// Returns null when the asset cannot be read, or has not answered within
/// [_readTimeout]; a scan carries on without it. Dart cannot cancel the read,
/// so a download that overran finishes unattended.
Future<MediaSourceMetadata?> readGalleryAssetMetadata(
  AssetInfo asset,
  PhotoPickerService photoPickerService,
) async {
  try {
    return await _readAssetMetadata(
      asset,
      photoPickerService,
    ).timeout(_readTimeout);
  } on Object catch (error, stackTrace) {
    _log.debug(
      'Failed to read metadata for gallery asset ${asset.id}',
      error: error,
      stackTrace: stackTrace,
    );
    return null;
  }
}

Future<MediaSourceMetadata?> _readAssetMetadata(
  AssetInfo asset,
  PhotoPickerService photoPickerService,
) async {
  final nativeMetadata = await photoPickerService.getAssetMetadata(asset.id);
  if (nativeMetadata != null &&
      (nativeMetadata.takenAt != null || !asset.isVideo)) {
    return nativeMetadata;
  }

  final path = await photoPickerService.getFilePath(asset.id);
  if (path == null) return null;
  return ExifExtractor().extract(File(path));
}
