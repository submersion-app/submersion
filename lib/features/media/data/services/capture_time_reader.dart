import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'package:submersion/features/media/data/services/exif_date_parser.dart';

/// Reads the capture time from a media file's own container metadata using
/// pure-Dart parsers (no native plugins), for the platforms and files where
/// `native_exif` yields nothing (macOS/Windows/Linux, or any file it cannot
/// date). Returns a wall-clock-UTC [DateTime] — the same frame
/// `DivePhotoMatcher` compares dive times in — or null when no reliable capture
/// time is present, leaving the caller to fall back to the file mtime.
///
/// - JPEG: EXIF `DateTimeOriginal` (via `package:image`, EXIF-only, no pixel
///   decode).
/// - MP4/MOV/M4V: the `moov > mvhd` `creation_time` from the ISO-BMFF/QuickTime
///   container.
DateTime? readLocalCaptureTime(File file, String mime) {
  switch (mime) {
    case 'image/jpeg':
      return _readJpegExifDate(file);
    case 'video/mp4':
    case 'video/quicktime':
    case 'video/x-m4v':
      return _readMp4CreationTime(file);
    default:
      return null;
  }
}

DateTime? _readJpegExifDate(File file) {
  try {
    final exif = img.decodeJpgExif(file.readAsBytesSync());
    if (exif == null) return null;
    // EXIF date tags are ASCII "YYYY:MM:DD HH:MM:SS". Prefer the shutter time
    // (DateTimeOriginal), then when it was digitized, then the basic file
    // DateTime, so files that omit the richer tags still get a real date.
    final raw =
        exif.exifIfd['DateTimeOriginal'] ??
        exif.exifIfd['DateTimeDigitized'] ??
        exif.imageIfd['DateTime'];
    return parseExifDateTimeOriginal(raw?.toString());
  } on Object {
    // Truncated/corrupt JPEG or an unreadable file: fall back to mtime.
    return null;
  }
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
    final moov = _findBox(raf, 0, end, 'moov');
    if (moov == null) return null;
    final mvhd = _findBox(raf, moov.start, moov.end, 'mvhd');
    if (mvhd == null) return null;

    final version = raf.readByteAt(mvhd.start);
    // creation_time follows the 1-byte version + 3 flag bytes. It is uint32 in
    // a v0 header and uint64 in a v1 header.
    final creation = version == 1
        ? _readU64(raf, mvhd.start + 4)
        : _readU32(raf, mvhd.start + 4);
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

/// Half-open byte range [start, end) of a box's content (payload).
class _BoxRange {
  const _BoxRange(this.start, this.end);
  final int start;
  final int end;
}

/// Returns the content range of the first sibling box of [type] within
/// [start, end), or null. Handles the 64-bit size form (size field == 1) and
/// the "extends to end of file" form (size field == 0).
_BoxRange? _findBox(RandomAccessFile raf, int start, int end, String type) {
  var pos = start;
  while (pos + 8 <= end) {
    raf.setPositionSync(pos);
    final header = raf.readSync(8);
    if (header.length < 8) return null;
    var size = _beU32(header, 0);
    var headerLen = 8;
    if (size == 1) {
      final ext = raf.readSync(8);
      if (ext.length < 8) return null;
      size = _beU64(ext, 0);
      headerLen = 16;
    } else if (size == 0) {
      size = end - pos;
    }
    if (size < headerLen || pos + size > end) return null;
    final boxType = String.fromCharCodes(header, 4, 8);
    if (boxType == type) return _BoxRange(pos + headerLen, pos + size);
    pos += size;
  }
  return null;
}

extension _ReadAt on RandomAccessFile {
  int readByteAt(int position) {
    setPositionSync(position);
    return readSync(1).first;
  }
}

int _readU32(RandomAccessFile raf, int position) {
  raf.setPositionSync(position);
  return _beU32(raf.readSync(4), 0);
}

int _readU64(RandomAccessFile raf, int position) {
  raf.setPositionSync(position);
  return _beU64(raf.readSync(8), 0);
}

int _beU32(Uint8List b, int o) =>
    (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3];

int _beU64(Uint8List b, int o) => (_beU32(b, o) << 32) | _beU32(b, o + 4);
