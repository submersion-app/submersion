import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show compute;
import 'package:native_exif/native_exif.dart';

import 'package:submersion/core/util/wall_clock_utc.dart';
import 'package:submersion/features/media/data/services/capture_time_reader.dart';
import 'package:submersion/features/media/data/services/exif_date_parser.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';

const _isolateThresholdBytes = 5 * 1024 * 1024;

/// Extracts [MediaSourceMetadata] from a local file.
///
/// `native_exif` is the primary reader on iOS/Android (it also handles HEIC).
/// It has no macOS/Windows/Linux implementation, so on desktop `Exif.fromPath`
/// throws `MissingPluginException`; the extractor then reads the capture time
/// straight from the file's own container metadata with a pure-Dart parser
/// ([readLocalCaptureTime]) that works on every platform. Only if that also
/// yields nothing does `takenAt` fall back to the file mtime — which is the
/// copy-to-disk time and would not match the dive window.
///
/// Files larger than 5 MB run in a background isolate via `compute()` so the UI
/// thread stays responsive during folder picks of large libraries. Returns null
/// only if the file does not exist.
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
  final mtime = asWallClockUtc(file.lastModifiedSync());
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
      takenAt = parseExifDateTimeOriginal(
        attrs['DateTimeOriginal']?.toString(),
      );

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
    // native_exif throws PlatformException on unsupported formats, and
    // MissingPluginException on macOS/Windows/Linux where it has no
    // implementation at all. Both are treated as "no native EXIF"; the
    // pure-Dart fallback below recovers takenAt where possible.
  }

  // On desktop (and for any file native_exif could not date), recover the
  // capture time from the file's own container metadata (JPEG EXIF or the
  // MP4/MOV mvhd) so it lands inside the dive window instead of defaulting to
  // the copy-to-disk mtime.
  takenAt ??= readLocalCaptureTime(file, mime);

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
