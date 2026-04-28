import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show compute;
import 'package:native_exif/native_exif.dart';

import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';

const _isolateThresholdBytes = 5 * 1024 * 1024;

/// Extracts [MediaSourceMetadata] from a local file via `native_exif`.
///
/// Files larger than 5 MB run in a background isolate via `compute()` so
/// the UI thread stays responsive during folder picks of large libraries.
/// On EXIF parse failure (unsupported format, corrupt header) the
/// extractor falls back to the file's mtime as `takenAt` and returns
/// the rest of [MediaSourceMetadata] populated by extension-based mime
/// inference. Returns null only if the file does not exist.
class ExifExtractor {
  Future<MediaSourceMetadata?> extract(File file) async {
    if (!file.existsSync()) return null;
    final size = file.lengthSync();
    if (size > _isolateThresholdBytes) {
      return compute(_extractIsolate, file.path);
    }
    return _extract(file.path);
  }
}

Future<MediaSourceMetadata?> _extractIsolate(String path) => _extract(path);

Future<MediaSourceMetadata?> _extract(String path) async {
  final file = File(path);
  if (!file.existsSync()) return null;
  // Match codebase convention: wall-clock-UTC. The matcher (DivePhotoMatcher)
  // compares photo takenAt against dive times stored as DateTime.utc(...) of
  // the dive computer's displayed digits. File.lastModifiedSync() returns a
  // local DateTime; reinterpret its calendar fields as UTC so the matcher
  // sees a directly comparable instant.
  final rawMtime = file.lastModifiedSync();
  final mtime = DateTime.utc(
    rawMtime.year,
    rawMtime.month,
    rawMtime.day,
    rawMtime.hour,
    rawMtime.minute,
    rawMtime.second,
  );
  final ext = path.split('.').last.toLowerCase();
  final mime = _mimeFromExtension(ext);

  DateTime? takenAt;
  double? lat;
  double? lon;
  int? width;
  int? height;

  try {
    final exif = await Exif.fromPath(path);
    Map<String, Object?>? attrs;
    try {
      attrs = await exif.getAttributes();
    } finally {
      await exif.close();
    }

    if (attrs != null) {
      // DateTimeOriginal is returned as a string in "YYYY:MM:DD HH:MM:SS" format.
      takenAt = _parseExifDate(attrs['DateTimeOriginal']?.toString());

      // GPS values are returned as doubles by native_exif; refs are strings.
      final rawLat = attrs['GPSLatitude'];
      final latRef = attrs['GPSLatitudeRef'];
      final rawLon = attrs['GPSLongitude'];
      final lonRef = attrs['GPSLongitudeRef'];

      if (rawLat is double && latRef is String) {
        lat = rawLat * (latRef == 'S' ? -1 : 1);
      }
      if (rawLon is double && lonRef is String) {
        lon = rawLon * (lonRef == 'W' ? -1 : 1);
      }

      // Dimension tags may be int or string depending on the platform channel.
      width = _parseInt(attrs['PixelXDimension'] ?? attrs['ImageWidth']);
      height = _parseInt(attrs['PixelYDimension'] ?? attrs['ImageLength']);
    }
  } on Object {
    // native_exif throws PlatformException on unsupported formats; treat
    // as "no EXIF available" and fall through to mtime fallback for takenAt.
  }

  return MediaSourceMetadata(
    takenAt: takenAt ?? mtime,
    latitude: lat,
    longitude: lon,
    width: width,
    height: height,
    // Video duration extraction requires a separate package; left null here.
    durationSeconds: null,
    mimeType: mime,
  );
}

int? _parseInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  return int.tryParse(value.toString());
}

DateTime? _parseExifDate(String? raw) {
  if (raw == null) return null;
  // EXIF format: "YYYY:MM:DD HH:MM:SS". Returned as DateTime.utc(...) so
  // the digits land in the same wall-clock-UTC frame as dive times. See
  // DivePhotoMatcher for the comparison side.
  try {
    final parts = raw.split(' ');
    if (parts.length != 2) return null;
    final dateParts = parts[0].split(':');
    final timeParts = parts[1].split(':');
    if (dateParts.length != 3 || timeParts.length != 3) return null;
    return DateTime.utc(
      int.parse(dateParts[0]),
      int.parse(dateParts[1]),
      int.parse(dateParts[2]),
      int.parse(timeParts[0]),
      int.parse(timeParts[1]),
      int.parse(timeParts[2]),
    );
  } on FormatException {
    return null;
  }
}

String _mimeFromExtension(String ext) {
  switch (ext) {
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'heic':
      return 'image/heic';
    case 'heif':
      return 'image/heif';
    case 'webp':
      return 'image/webp';
    case 'gif':
      return 'image/gif';
    case 'mp4':
      return 'video/mp4';
    case 'mov':
      return 'video/quicktime';
    case 'm4v':
      return 'video/x-m4v';
    default:
      return 'application/octet-stream';
  }
}
