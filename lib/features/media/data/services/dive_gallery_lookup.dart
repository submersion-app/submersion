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
abstract final class DiveGalleryLookup {
  /// The library's photos and videos from `[windowStart, windowEnd]`, a dive
  /// window in wall-clock-as-UTC, newest first.
  ///
  /// A photo found through its EXIF comes back with `createDateTime` set to
  /// that wall-time, so what is imported from it stores the time the diver
  /// saw, and lands in the right place on the profile.
  ///
  /// [isActive] is asked before each read, so a caller that has gone away
  /// stops the fetching. What had been found by then is returned.
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

    bool stillWanted() => isActive == null || isActive();

    List<AssetInfo> newestFirst() =>
        found.values.toList()
          ..sort((a, b) => b.createDateTime.compareTo(a.createDateTime));

    var insideLeft = _clockSamplesInside;
    var outsideLeft = _clockSamplesOutside;
    var clocksAgree = true;
    for (final photo in photos) {
      final inside = found.containsKey(photo.id);
      if ((inside ? insideLeft : outsideLeft) == 0) continue;
      if (!stillWanted()) break;
      final wallTime = await wallTimeOf(photo);
      if (wallTime == null) continue;

      final deviceDigits = asWallClockUtc(photo.createDateTime);
      if (wallTime.difference(deviceDigits).abs() >= _sameClockTolerance) {
        clocksAgree = false;
        break;
      }
      if (inside) {
        insideLeft--;
      } else {
        outsideLeft--;
      }
    }
    if (clocksAgree) return newestFirst();

    for (final photo in photos) {
      if (!stillWanted()) break;
      final wallTime = await wallTimeOf(photo);
      if (wallTime == null) continue;

      if (inWindow(wallTime)) {
        found[photo.id] = photo.copyWith(
          createDateTime: fromWallClockUtc(wallTime),
        );
      } else {
        found.remove(photo.id);
      }
    }

    return newestFirst();
  }

  /// How far [asset]'s digits on this device are from the window; zero
  /// inside it. The nearest photo is the likeliest to be from the same trip.
  static Duration _gapToWindow(AssetInfo asset, DateTime start, DateTime end) {
    final digits = asWallClockUtc(asset.createDateTime);
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
/// Returns null when the asset cannot be read; a scan carries on without it.
Future<MediaSourceMetadata?> readGalleryAssetMetadata(
  AssetInfo asset,
  PhotoPickerService photoPickerService,
) async {
  try {
    final nativeMetadata = await photoPickerService.getAssetMetadata(asset.id);
    if (nativeMetadata != null &&
        (nativeMetadata.takenAt != null || !asset.isVideo)) {
      return nativeMetadata;
    }

    final path = await photoPickerService.getFilePath(asset.id);
    if (path == null) return null;
    return await ExifExtractor().extract(File(path));
  } on Object catch (error, stackTrace) {
    _log.debug(
      'Failed to read metadata for gallery asset ${asset.id}',
      error: error,
      stackTrace: stackTrace,
    );
    return null;
  }
}
