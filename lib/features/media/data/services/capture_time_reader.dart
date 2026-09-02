import 'dart:io';

import 'package:image/image.dart' as img;

import 'package:submersion/features/media/data/services/exif_date_parser.dart';
import 'package:submersion/features/media/data/services/isobmff_boxes.dart';
import 'package:submersion/features/media/data/services/local_exif_loader.dart';

/// Reads the capture time from a media file's own container metadata using
/// pure-Dart parsers (no native plugins), for the platforms and files where
/// `native_exif` yields nothing (macOS/Windows/Linux, or any file it cannot
/// date). Returns a wall-clock-UTC [DateTime], the same frame
/// `DivePhotoMatcher` compares dive times in, or null when no reliable capture
/// time is present, leaving the caller to fall back to the file mtime.
///
/// - JPEG and HEIC/HEIF: EXIF `DateTimeOriginal`, loaded once through
///   [readLocalExif] (EXIF-only, no pixel decode).
/// - MP4/MOV/M4V: the `moov > mvhd` `creation_time` from the ISO-BMFF/QuickTime
///   container.
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
      return _readMp4CreationTime(file);
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

// Seconds between the QuickTime/ISO-BMFF epoch (1904-01-01) and the Unix epoch.
// This is a whole number of days, so the epoch shift preserves the time-of-day
// digits exactly (only the date rolls) when reconstructing the DateTime.
const _secondsBetween1904And1970 = 2082844800;

DateTime? _readMp4CreationTime(File file) {
  RandomAccessFile? raf;
  try {
    raf = file.openSync();
    final end = raf.lengthSync();
    // The movie header (mvhd) lives inside moov. Cameras such as GoPro place
    // moov AFTER the multi-hundred-MB mdat, so we walk top-level boxes by size,
    // seeking past mdat without ever reading its bytes.
    final moov = findBox(raf, 0, end, 'moov');
    if (moov == null) return null;
    final mvhd = findBox(raf, moov.start, moov.end, 'mvhd');
    if (mvhd == null) return null;

    final version = readByteAt(raf, mvhd.start);
    // Only v0/v1 mvhd headers exist. Bail on anything else rather than
    // mis-reading a corrupt byte as v0 and emitting a bogus timestamp.
    if (version != 0 && version != 1) return null;
    // creation_time follows the 1-byte version + 3 flag bytes. It is uint32 in
    // a v0 header and uint64 in a v1 header.
    final creation = version == 1
        ? readU64At(raf, mvhd.start + 4)
        : readU32At(raf, mvhd.start + 4);
    if (creation == 0) return null; // 0 == "unknown"; caller uses mtime.

    // GoPro (and most cameras) write the LOCAL wall clock into creation_time.
    // Reconstructing it as a UTC DateTime preserves those digits as
    // wall-clock-UTC, matching how EXIF and mtime are handled here.
    return DateTime.fromMillisecondsSinceEpoch(
      (creation - _secondsBetween1904And1970) * 1000,
      isUtc: true,
    );
  } on Object {
    return null;
  } finally {
    raf?.closeSync();
  }
}
