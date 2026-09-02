import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'package:submersion/features/media/data/services/isobmff_boxes.dart';

/// Loads the EXIF block of a JPEG or HEIC/HEIF file with pure Dart, for the
/// platforms where `native_exif` has no implementation. One parse serves
/// every consumer (capture time, GPS); callers never decode pixels.
///
/// Returns null for unsupported mimes, unreadable or corrupt files, and files
/// that simply carry no EXIF.
img.ExifData? readLocalExif(File file, String mime) {
  try {
    switch (mime) {
      case 'image/jpeg':
        return img.decodeJpgExif(file.readAsBytesSync());
      case 'image/heic':
      case 'image/heif':
        return _readHeicExif(file);
      default:
        return null;
    }
  } on Object {
    return null;
  }
}

// Upper bounds on HEIC reads. Real `meta` boxes and `Exif` items are tens of
// KB (the meta box carries no pixel data), so these leave ~100x headroom for
// multi-image HEICs and cameras with fat MakerNotes while keeping the worst
// case small.
//
// Neither cap is the primary guard: findBox refuses any box whose declared
// size runs past EOF, and the extent check below rejects offset + length
// past EOF, so a small crafted file cannot ask for a large read in the first
// place. What the caps bound is the honest-but-hostile case -- a genuinely
// large file whose meta box or Exif extent is correspondingly large -- which
// matters because a folder import runs this over every picked file.
const _maxMetaBytes = 8 * 1024 * 1024;
const _maxExifItemBytes = 4 * 1024 * 1024;

/// Reads EXIF from a HEIC/HEIF file. HEIC is ISO-BMFF: the EXIF lives in a
/// metadata item declared by the `meta > iinf` box (type `Exif`) and located
/// by `meta > iloc`. We read only the `meta` box and the Exif item's extent
/// (not the multi-MB image data), then hand the embedded TIFF block to
/// `package:image`'s EXIF parser.
img.ExifData? _readHeicExif(File file) {
  RandomAccessFile? raf;
  try {
    raf = file.openSync();
    final end = raf.lengthSync();
    final meta = findBox(raf, 0, end, 'meta');
    if (meta == null) return null;
    // `meta` is a FullBox: its child boxes start 4 (version+flags) bytes in.
    final metaLen = meta.end - meta.start - 4;
    if (metaLen <= 0 || metaLen > _maxMetaBytes) return null;
    final metaBytes = readBytesAt(raf, meta.start + 4, metaLen);

    final iinf = findBoxInBytes(metaBytes, 0, metaBytes.length, 'iinf');
    final iloc = findBoxInBytes(metaBytes, 0, metaBytes.length, 'iloc');
    if (iinf == null || iloc == null) return null;

    final itemId = _heicExifItemId(metaBytes, iinf.start, iinf.end);
    if (itemId == null) return null;
    final extent = _heicExifExtent(metaBytes, iloc.start, iloc.end, itemId);
    if (extent == null) return null;
    // Reject a corrupt/crafted extent that points past EOF or advertises an
    // absurd length. Real EXIF items are a few KB.
    if (extent.offset < 0 ||
        extent.length <= 0 ||
        extent.length > _maxExifItemBytes ||
        extent.offset + extent.length > end) {
      return null;
    }

    final item = readBytesAt(raf, extent.offset, extent.length);
    final tiff = _tiffHeaderOffset(item);
    if (tiff == null) return null;
    return img.ExifData.fromInputBuffer(img.InputBuffer(item.sublist(tiff)));
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
    count = beU16(b, p);
    p += 2;
  } else {
    count = beU32(b, p);
    p += 4;
  }
  for (var i = 0; i < count && p + 8 <= end; i++) {
    final size = beU32(b, p);
    if (size < 8 || p + size > end) return null;
    final infeEnd = p + size;
    final infeVersion = b[p + 8];
    final idBytes = infeVersion >= 3 ? 4 : 2; // item_ID width
    final itemId = infeVersion >= 3 ? beU32(b, p + 12) : beU16(b, p + 12);
    // item_type follows: infe header (8) + version/flags (4) + item_ID +
    // item_protection_index (2). Bound the read to THIS infe box so a corrupt
    // size can't match an 'Exif' fourCC that belongs to a following entry.
    final typePos = p + 12 + idBytes + 2;
    if (typePos + 4 <= infeEnd && fourCC(b, typePos) == 'Exif') return itemId;
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
    itemCount = beU16(b, p);
    p += 2;
  } else {
    itemCount = beU32(b, p);
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
    final id = version < 2 ? beU16(b, p) : beU32(b, p);
    p += version < 2 ? 2 : 4;
    if (version == 1 || version == 2) p += 2; // construction_method
    p += 2; // data_reference_index
    final baseOffset = readSized(baseOffsetSize);
    final extentCount = beU16(b, p);
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

/// The HEIC `Exif` item begins with a 4-byte big-endian offset to the TIFF
/// header (counted from just past that field). Use it directly; fall back to a
/// bounded scan only when the declared offset is out of range or does not point
/// at a TIFF signature, so malformed input degrades gracefully instead of
/// mis-locating an earlier byte sequence.
int? _tiffHeaderOffset(Uint8List b) {
  if (b.length >= 8) {
    final declared = 4 + beU32(b, 0);
    if (declared + 4 <= b.length && _isTiffHeader(b, declared)) return declared;
  }
  for (var i = 0; i + 4 <= b.length; i++) {
    if (_isTiffHeader(b, i)) return i;
  }
  return null;
}

/// A TIFF header is `II*\0` (little-endian) or `MM\0*` (big-endian).
bool _isTiffHeader(Uint8List b, int o) =>
    (b[o] == 0x49 &&
        b[o + 1] == 0x49 &&
        b[o + 2] == 0x2a &&
        b[o + 3] == 0x00) ||
    (b[o] == 0x4d && b[o + 1] == 0x4d && b[o + 2] == 0x00 && b[o + 3] == 0x2a);

class _Extent {
  const _Extent(this.offset, this.length);
  final int offset;
  final int length;
}
