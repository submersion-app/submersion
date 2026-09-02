import 'dart:io';

import 'package:image/image.dart' as img;

import 'package:submersion/features/media/data/services/gpmf_gps_reader.dart';
import 'package:submersion/features/media/data/services/gps_fix.dart';
import 'package:submersion/features/media/data/services/local_exif_loader.dart';
import 'package:submersion/features/media/data/services/quicktime_location_reader.dart';

/// Reads a position from a media file's own metadata with pure Dart, for the
/// platforms and files where `native_exif` yields nothing: the EXIF GPS IFD
/// for stills, the QuickTime location atom or GoPro telemetry for video.
/// Returns null when the file carries no plausible fix.
GpsFix? readLocalGps(File file, String mime) {
  try {
    switch (mime) {
      case 'image/jpeg':
      case 'image/heic':
      case 'image/heif':
        final exif = readLocalExif(file, mime);
        return exif == null ? null : gpsFromExif(exif);
      case 'video/mp4':
      case 'video/quicktime':
      case 'video/x-m4v':
        // Phones and most cameras write a location atom; GoPro writes
        // telemetry instead. Try the cheap atom first.
        return readQuickTimeLocation(file) ?? readGpmfGps(file);
      default:
        return null;
    }
  } on Object {
    return null;
  }
}

/// EXIF stores each axis as three unsigned rationals (degrees, minutes,
/// seconds) in the GPS IFD, with the hemisphere in a separate ASCII tag.
/// A reader that ignores the ref tag puts every western-hemisphere dive in
/// the wrong ocean, so both are read here.
GpsFix? gpsFromExif(img.ExifData exif) {
  final gps = exif.gpsIfd;
  final lat = _degrees(gps[0x0002]);
  final lon = _degrees(gps[0x0004]);
  if (lat == null || lon == null) return null;
  final latRef = gps[0x0001]?.toString().trim().toUpperCase();
  final lonRef = gps[0x0003]?.toString().trim().toUpperCase();
  final signedLat = latRef == 'S' ? -lat : lat;
  final signedLon = lonRef == 'W' ? -lon : lon;
  if (!isPlausibleFix(signedLat, signedLon)) return null;
  return (latitude: signedLat, longitude: signedLon);
}

/// Sums a (deg, min, sec) rational triple, the form cameras write. Also
/// accepts a single value of any numeric type (a decimal degree), which is
/// what `package:image`'s typed setters store and what some writers emit.
double? _degrees(img.IfdValue? value) {
  if (value == null) return null;
  if (value is! img.IfdValueRational) {
    if (value.length != 1) return null;
    final d = value.toDouble();
    return d.isFinite ? d : null;
  }
  final parts = value.value;
  if (parts.isEmpty) return null;
  double part(int i) {
    if (i >= parts.length) return 0;
    final r = parts[i];
    if (r.denominator == 0) return double.nan;
    return r.numerator / r.denominator;
  }

  final degrees = part(0) + part(1) / 60 + part(2) / 3600;
  return degrees.isFinite ? degrees : null;
}
