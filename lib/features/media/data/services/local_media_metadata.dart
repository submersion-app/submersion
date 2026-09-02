import 'dart:io';

import 'package:submersion/features/media/data/services/capture_time_reader.dart';
import 'package:submersion/features/media/data/services/gps_fix.dart';
import 'package:submersion/features/media/data/services/local_exif_loader.dart';
import 'package:submersion/features/media/data/services/local_gps_reader.dart';

/// What a local file carries about itself in its own container metadata.
typedef LocalMediaMetadata = ({DateTime? capturedUtc, GpsFix? fix});

/// Reads the capture time and the position of one file in a single pass, for
/// the callers that want both ([ExifExtractor], the desktop picker).
///
/// A still's EXIF block is parsed once here and answers both questions;
/// calling [readLocalCaptureTime] and [readLocalGps] in turn reads and parses
/// the file twice. Video keeps the two container walks: they seek by box size
/// and never touch `mdat`, so a second walk over a multi-GB clip is measured
/// in microseconds, and sharing one handle would mean threading a
/// [RandomAccessFile] through three readers for no gain.
///
/// Either half is null when the file carries no reliable value for it; the
/// caller decides what to fall back to.
LocalMediaMetadata readLocalMediaMetadata(File file, String mime) {
  switch (mime) {
    case 'image/jpeg':
    case 'image/heic':
    case 'image/heif':
      try {
        final exif = readLocalExif(file, mime);
        if (exif == null) return (capturedUtc: null, fix: null);
        return (capturedUtc: captureTimeFromExif(exif), fix: gpsFromExif(exif));
      } on Object {
        // Matches readLocalGps: a corrupt tag value is "no metadata", never
        // a failed import.
        return (capturedUtc: null, fix: null);
      }
    default:
      return (
        capturedUtc: readLocalCaptureTime(file, mime),
        fix: readLocalGps(file, mime),
      );
  }
}
