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
/// - HEIC/HEIF: EXIF from the ISO-BMFF `meta` box's `Exif` item (iPhone's
///   default photo format; `package:image` cannot decode HEIC pixels, but the
///   embedded EXIF is a standard TIFF block once located).
/// - MP4/MOV/M4V: the `moov > mvhd` `creation_time` from the ISO-BMFF/QuickTime
///   container.
DateTime? readLocalCaptureTime(File file, String mime) {
  switch (mime) {
    case 'image/jpeg':
      return _readJpegExifDate(file);
    case 'image/heic':
    case 'image/heif':
      return _readHeicExifDate(file);
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
    return _dateFromExif(exif);
  } on Object {
    // Truncated/corrupt JPEG or an unreadable file: fall back to mtime.
    return null;
  }
}

/// Pulls a wall-clock-UTC date from a parsed [img.ExifData]. EXIF date tags are
/// ASCII "YYYY:MM:DD HH:MM:SS"; prefer the shutter time (DateTimeOriginal),
/// then when it was digitized, then the basic file DateTime.
DateTime? _dateFromExif(img.ExifData exif) {
  final raw =
      exif.exifIfd['DateTimeOriginal'] ??
      exif.exifIfd['DateTimeDigitized'] ??
      exif.imageIfd['DateTime'];
  return parseExifDateTimeOriginal(raw?.toString());
}

/// Reads EXIF from a HEIC/HEIF file. HEIC is ISO-BMFF: the EXIF lives in a
/// metadata item declared by the `meta > iinf` box (type `Exif`) and located
/// by `meta > iloc`. We read only the `meta` box and the Exif item's extent
/// (not the multi-MB image data), then hand the embedded TIFF block to
/// `package:image`'s EXIF parser.
DateTime? _readHeicExifDate(File file) {
  RandomAccessFile? raf;
  try {
    raf = file.openSync();
    final end = raf.lengthSync();
    final meta = _findBox(raf, 0, end, 'meta');
    if (meta == null) return null;
    // `meta` is a FullBox: its child boxes start 4 (version+flags) bytes in.
    raf.setPositionSync(meta.start + 4);
    final metaBytes = raf.readSync(meta.end - meta.start - 4);

    final iinf = _findBoxInBytes(metaBytes, 0, metaBytes.length, 'iinf');
    final iloc = _findBoxInBytes(metaBytes, 0, metaBytes.length, 'iloc');
    if (iinf == null || iloc == null) return null;

    final itemId = _heicExifItemId(metaBytes, iinf.start, iinf.end);
    if (itemId == null) return null;
    final extent = _heicExifExtent(metaBytes, iloc.start, iloc.end, itemId);
    if (extent == null) return null;

    raf.setPositionSync(extent.offset);
    final item = raf.readSync(extent.length);
    final tiff = _findTiffHeader(item);
    if (tiff == null) return null;

    final exif = img.ExifData.fromInputBuffer(
      img.InputBuffer(item.sublist(tiff)),
    );
    return _dateFromExif(exif);
  } on Object {
    return null;
  } finally {
    raf?.closeSync();
  }
}

/// Finds the `Exif` item's id in an `iinf` box's content range. Each `infe`
/// entry carries the item id (uint16 in v<3, uint32 in v3+) followed by the
/// protection index and a four-char item type.
int? _heicExifItemId(Uint8List b, int start, int end) {
  final version = b[start];
  var p = start + 4; // skip version + flags
  final int count;
  if (version == 0) {
    count = _beU16(b, p);
    p += 2;
  } else {
    count = _beU32(b, p);
    p += 4;
  }
  for (var i = 0; i < count && p + 8 <= end; i++) {
    final size = _beU32(b, p);
    if (size < 8 || p + size > end) return null;
    final infeVersion = b[p + 8];
    var q = p + 12; // skip infe box header (8) + version+flags (4)
    if (infeVersion >= 3) {
      q += 4; // item_ID uint32
    } else {
      q += 2; // item_ID uint16
    }
    final itemId = infeVersion >= 3 ? _beU32(b, p + 12) : _beU16(b, p + 12);
    q += 2; // item_protection_index
    if (q + 4 <= end && _fourCC(b, q) == 'Exif') return itemId;
    p += size;
  }
  return null;
}

/// Resolves the byte extent (absolute offset + length) of item [wantId] from an
/// `iloc` box's content range.
_Extent? _heicExifExtent(Uint8List b, int start, int end, int wantId) {
  final version = b[start];
  var p = start + 4; // skip version + flags
  final offsetSize = b[p] >> 4;
  final lengthSize = b[p] & 0xf;
  final baseOffsetSize = b[p + 1] >> 4;
  final indexSize = b[p + 1] & 0xf;
  p += 2;
  final int itemCount;
  if (version < 2) {
    itemCount = _beU16(b, p);
    p += 2;
  } else {
    itemCount = _beU32(b, p);
    p += 4;
  }

  int readSized(int n) {
    var v = 0;
    for (var i = 0; i < n; i++) {
      v = (v << 8) | b[p + i];
    }
    p += n;
    return v;
  }

  for (var i = 0; i < itemCount && p < end; i++) {
    final id = version < 2 ? _beU16(b, p) : _beU32(b, p);
    p += version < 2 ? 2 : 4;
    if (version == 1 || version == 2) p += 2; // construction_method
    p += 2; // data_reference_index
    final baseOffset = readSized(baseOffsetSize);
    final extentCount = _beU16(b, p);
    p += 2;
    for (var e = 0; e < extentCount; e++) {
      if ((version == 1 || version == 2) && indexSize > 0) readSized(indexSize);
      final off = readSized(offsetSize);
      final len = readSized(lengthSize);
      if (id == wantId) return _Extent(baseOffset + off, len);
    }
  }
  return null;
}

/// Locates the TIFF header (`II*\0` or `MM\0*`) that begins the EXIF block
/// inside a HEIC `Exif` item (which is prefixed by a small offset header).
int? _findTiffHeader(Uint8List b) {
  for (var i = 0; i + 4 <= b.length; i++) {
    final a = b[i], c = b[i + 1], d = b[i + 2], e = b[i + 3];
    if ((a == 0x49 && c == 0x49 && d == 0x2a && e == 0x00) ||
        (a == 0x4d && c == 0x4d && d == 0x00 && e == 0x2a)) {
      return i;
    }
  }
  return null;
}

/// Byte-buffer twin of [_findBox], for walking sub-boxes already read into
/// memory (e.g. inside a `meta` box).
_BoxRange? _findBoxInBytes(Uint8List b, int start, int end, String type) {
  var pos = start;
  while (pos + 8 <= end) {
    var size = _beU32(b, pos);
    var headerLen = 8;
    if (size == 1) {
      if (pos + 16 > end) return null;
      size = _beU64(b, pos + 8);
      headerLen = 16;
    } else if (size == 0) {
      size = end - pos;
    }
    if (size < headerLen || pos + size > end) return null;
    if (_fourCC(b, pos + 4) == type) {
      return _BoxRange(pos + headerLen, pos + size);
    }
    pos += size;
  }
  return null;
}

class _Extent {
  const _Extent(this.offset, this.length);
  final int offset;
  final int length;
}

int _beU16(Uint8List b, int o) => (b[o] << 8) | b[o + 1];

String _fourCC(Uint8List b, int o) => String.fromCharCodes(b, o, o + 4);

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
    // Only v0/v1 mvhd headers exist. Bail on anything else rather than
    // mis-reading a corrupt byte as v0 and emitting a bogus timestamp.
    if (version != 0 && version != 1) return null;
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
