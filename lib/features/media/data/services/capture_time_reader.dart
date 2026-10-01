import 'dart:io';

import 'package:image/image.dart' as img;

import 'package:submersion/features/media/data/services/exif_date_parser.dart';
import 'package:submersion/features/media/data/services/local_exif_loader.dart';
import 'package:submersion/features/media/data/services/video_capture_time_reader.dart';

/// Reads the capture time from a media file's own container metadata using
/// pure-Dart parsers (no native plugins), for the platforms and files where
/// `native_exif` yields nothing (macOS/Windows/Linux, or any file it cannot
/// date). Returns a wall-clock-UTC [DateTime], the same frame
/// `DivePhotoMatcher` compares dive times in, or null when no reliable capture
/// time is present, leaving the caller to fall back to the file mtime.
///
/// - JPEG and HEIC/HEIF: EXIF `DateTimeOriginal`, loaded once through
///   [readLocalExif] (EXIF-only, no pixel decode).
/// - MP4/MOV/M4V: the first usable of the QuickTime creationdate key, the
///   `©day` tag and the `mvhd` creation time; see [readVideoCaptureTime] for
///   the order and for how an `mvhd` value is placed in UTC or local time.
DateTime? readLocalCaptureTime(File file, String mime) {
  switch (mime) {
    case 'image/jpeg':
    case 'image/heic':
    case 'image/heif':
      final exif = readLocalExif(file, mime);
      return exif == null ? null : captureTimeFromExif(exif);
    case 'video/mp4':
    case 'video/quicktime':
    case 'video/x-m4v':
      return readVideoCaptureTime(file);
    default:
      return null;
  }
}

/// Pulls a wall-clock-UTC date from a parsed [img.ExifData]. EXIF date tags are
/// ASCII "YYYY:MM:DD HH:MM:SS"; prefer the shutter time (DateTimeOriginal),
/// then when it was digitized, then the basic file DateTime.
///
/// Public so a caller that has already parsed the EXIF for another reason can
/// reuse it instead of reading and parsing the file a second time; see
/// `readLocalMediaMetadata`.
DateTime? captureTimeFromExif(img.ExifData exif) {
  final raw =
      exif.exifIfd['DateTimeOriginal'] ??
      exif.exifIfd['DateTimeDigitized'] ??
      exif.imageIfd['DateTime'];
  return parseExifDateTimeOriginal(raw?.toString());
}
