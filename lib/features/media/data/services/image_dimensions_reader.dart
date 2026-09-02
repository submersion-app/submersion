import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'package:submersion/features/media/data/services/isobmff_boxes.dart';

/// The stored pixel size of an image, as its container declares it.
typedef ImageDimensions = ({int width, int height});

/// Reads an image's pixel dimensions from its container header, without
/// decoding pixels and, for the two formats that matter on a folder import,
/// without reading the file.
///
/// Dispatch is on the file's own magic bytes, not on [mime] -- [mime] only
/// gates images from video, so a photo whose name lies is still read
/// correctly.
///
/// The dimensions reported are the ones *stored* in the container. No
/// orientation is applied: a JPEG's EXIF `Orientation` tag and a HEIC's
/// `irot` property both leave the encoded frame alone, and the decoder this
/// reader replaced ignored them too. Matching tiers such as
/// `AssetResolutionService.matchByTimestampAndDimensions` compare for exact
/// equality against dimensions recorded the same way, so the convention
/// matters more than the choice.
///
/// Returns null for videos and for anything whose header cannot be read.
ImageDimensions? readImageDimensions(File file, String mime) {
  if (!mime.startsWith('image/')) return null;
  RandomAccessFile? raf;
  try {
    raf = file.openSync();
    final end = raf.lengthSync();
    if (end < 12) return null;
    final magic = readBytesAt(raf, 0, 12);
    if (_isJpeg(magic)) return _jpegDimensions(raf, end);
    if (_isIsoBmff(magic)) return _isoBmffDimensions(raf, end);
    return _decoderDimensions(raf, end);
  } on Object {
    // Unreadable, truncated, or malformed: dimensions are optional here.
    return null;
  } finally {
    raf?.closeSync();
  }
}

bool _isJpeg(Uint8List b) => b[0] == 0xff && b[1] == 0xd8 && b[2] == 0xff;

/// ISO base media file format: a `ftyp` box at offset 0. HEIC, HEIF and AVIF
/// all take the `meta > iprp` route below; other brands (MP4, MOV) never
/// reach here because [readImageDimensions] gates on an image mime.
bool _isIsoBmff(Uint8List b) => fourCC(b, 4) == 'ftyp';

// -- JPEG ------------------------------------------------------------------

/// Walks the JPEG segment chain to the first frame header and reads the
/// dimensions out of it.
///
/// This is the whole reason the reader exists. `JpegDecoder.startDecode`
/// yields a result only once it has seen both an SOF *and* an SOS, and
/// reaching the marker after the SOS means byte-scanning the entire
/// entropy-coded scan in Dart: ~26 ms on a 3.8 MB photo, for two integers
/// that were already on the table at the SOF. Seeking segment to segment
/// touches a few KB instead.
ImageDimensions? _jpegDimensions(RandomAccessFile raf, int end) {
  var pos = 2; // past the SOI matched by _isJpeg
  while (pos + 2 <= end) {
    final head = readBytesAt(raf, pos, 2);
    if (head.length < 2 || head[0] != 0xff) return null;
    final marker = head[1];
    pos += 2;

    // A marker may be preceded by any number of 0xFF fill bytes.
    if (marker == 0xff) {
      pos -= 1;
      continue;
    }
    // 0xFF00 is a stuffed data byte, which cannot appear between segments.
    if (marker == 0x00) return null;
    // Standalone markers carry no length payload: TEM, SOI, RSTn.
    if (marker == 0x01 ||
        marker == 0xd8 ||
        (marker >= 0xd0 && marker <= 0xd7)) {
      continue;
    }
    // EOI, or the start of the scan, with no frame header seen. Everything
    // past an SOS is entropy-coded data, and stepping through it is exactly
    // the cost being avoided.
    if (marker == 0xd9 || marker == 0xda) return null;

    if (pos + 2 > end) return null;
    final length = beU16(readBytesAt(raf, pos, 2), 0);
    // A segment shorter than its own length field, or one running past EOF,
    // is corrupt; stop rather than seek to a guessed position.
    if (length < 2 || pos + length > end) return null;

    if (_isFrameHeader(marker)) {
      // SOFn payload: [precision:1][height:2][width:2][components:1]...
      if (length < 8) return null;
      final frame = readBytesAt(raf, pos + 2, 5);
      final height = beU16(frame, 1);
      final width = beU16(frame, 3);
      if (width == 0 || height == 0) return null;
      return (width: width, height: height);
    }

    pos += length;
  }
  return null;
}

/// SOF0..SOF15 share one payload layout, so all of them answer. The three
/// markers that sit inside that range without being frame headers do not:
/// DHT (0xC4), JPG (0xC8) and DAC (0xCC).
bool _isFrameHeader(int marker) =>
    marker >= 0xc0 &&
    marker <= 0xcf &&
    marker != 0xc4 &&
    marker != 0xc8 &&
    marker != 0xcc;

// -- HEIC / HEIF / AVIF ----------------------------------------------------

/// Upper bound on the `meta` box read. Mirrors the cap in
/// `local_exif_loader.dart` and for the same reason: the box carries no pixel data, so a real one is tens of
/// KB, and a folder import runs this over every picked file.
const _maxMetaBytes = 8 * 1024 * 1024;

/// Reads the primary image item's `ispe` (image spatial extents) property.
///
/// The layout is `meta > iprp > ipco`, a flat list of item properties, with
/// `meta > iprp > ipma` associating 1-based indices into that list with item
/// ids and `meta > pitm` naming the primary item. Resolving the primary item
/// matters: a thumbnail's `ispe` is commonly the first one in `ipco`.
///
/// Before this route existed HEIC fell to `package:image`, which read the
/// whole file and then found no HEIC decoder at all -- a multi-MB read for a
/// guaranteed null, leaving every picked HEIC at 0x0.
ImageDimensions? _isoBmffDimensions(RandomAccessFile raf, int end) {
  final meta = findBox(raf, 0, end, 'meta');
  if (meta == null) return null;
  // `meta` is a FullBox: its children start 4 (version + flags) bytes in.
  final metaLen = meta.end - meta.start - 4;
  if (metaLen <= 0 || metaLen > _maxMetaBytes) return null;
  final metaBytes = readBytesAt(raf, meta.start + 4, metaLen);

  final iprp = findBoxInBytes(metaBytes, 0, metaBytes.length, 'iprp');
  if (iprp == null) return null;
  final ipco = findBoxInBytes(metaBytes, iprp.start, iprp.end, 'ipco');
  if (ipco == null) return null;

  final properties = findBoxesInBytes(metaBytes, ipco.start, ipco.end, 'ispe');
  if (properties.isEmpty) return null;

  final wanted = _primaryIspe(metaBytes, iprp, ipco);
  // A file with no usable pitm/ipma pair still has exactly one plausible
  // answer in the common single-image case: the first ispe.
  return _readIspe(metaBytes, wanted ?? properties.first);
}

/// Resolves the `ispe` associated with the `pitm` primary item, or null when
/// either the primary item or its association is missing.
BoxRange? _primaryIspe(Uint8List b, BoxRange iprp, BoxRange ipco) {
  final pitm = findBoxInBytes(b, 0, b.length, 'pitm');
  if (pitm == null) return null;
  final version = b[pitm.start];
  final idPos = pitm.start + 4;
  if (idPos + (version == 0 ? 2 : 4) > pitm.end) return null;
  final primaryId = version == 0 ? beU16(b, idPos) : beU32(b, idPos);

  final ipma = findBoxInBytes(b, iprp.start, iprp.end, 'ipma');
  if (ipma == null) return null;

  // Property indices are 1-based into ipco's full child list, which holds
  // `hvcC`, `colr`, `pixi` and `irot` alongside the `ispe` entries -- an item
  // is associated with several of them, in no guaranteed order, so every
  // association is tried and the one that lands on an ispe wins. The list has
  // to come from the shared walker: it is positional, so a child using the
  // 64-bit or to-end-of-range size form must still occupy exactly one slot.
  final children = boxesInBytes(b, ipco.start, ipco.end);
  for (final index in _propertyIndicesFor(b, ipma, primaryId)) {
    if (index < 1 || index > children.length) continue;
    final child = children[index - 1];
    if (child.type == 'ispe') return child.range;
  }
  return null;
}

/// Every property index associated with [wantId] in an `ipma` box, in
/// declaration order.
///
/// Entry layout: item_ID (uint16 in v0, uint32 in v1+), an association count,
/// then that many association records. Each record is one byte -- an
/// "essential" flag plus a 7-bit index -- unless flags bit 0 is set, in which
/// case it is two bytes with a 15-bit index.
List<int> _propertyIndicesFor(Uint8List b, BoxRange ipma, int wantId) {
  final version = b[ipma.start];
  final wideIndex = (b[ipma.start + 3] & 0x1) != 0;
  final idBytes = version < 1 ? 2 : 4;
  final indexBytes = wideIndex ? 2 : 1;

  var pos = ipma.start + 4;
  if (pos + 4 > ipma.end) return const [];
  final entryCount = beU32(b, pos);
  pos += 4;

  for (var i = 0; i < entryCount; i++) {
    if (pos + idBytes + 1 > ipma.end) return const [];
    final id = idBytes == 2 ? beU16(b, pos) : beU32(b, pos);
    pos += idBytes;
    final associationCount = b[pos];
    pos += 1;
    if (pos + associationCount * indexBytes > ipma.end) return const [];
    if (id == wantId) {
      return [
        for (var a = 0; a < associationCount; a++)
          if (wideIndex)
            beU16(b, pos + a * indexBytes) & 0x7fff
          else
            b[pos + a * indexBytes] & 0x7f,
      ];
    }
    pos += associationCount * indexBytes;
  }
  return const [];
}

/// `ispe` is a FullBox holding image_width then image_height as uint32.
ImageDimensions? _readIspe(Uint8List b, BoxRange ispe) {
  if (ispe.end - ispe.start < 12) return null;
  final width = beU32(b, ispe.start + 4);
  final height = beU32(b, ispe.start + 8);
  if (width == 0 || height == 0) return null;
  return (width: width, height: height);
}

// -- everything else -------------------------------------------------------

/// PNG, GIF, WebP, BMP and TIFF, whose `startDecode` really does stop at the
/// header. Only these formats pay the full-file read, and at roughly 0.6 ms
/// per 4 MB that read is not what this reader was written to remove.
ImageDimensions? _decoderDimensions(RandomAccessFile raf, int end) {
  final bytes = readBytesAt(raf, 0, end);
  final info = img.findDecoderForData(bytes)?.startDecode(bytes);
  if (info == null || info.width == 0 || info.height == 0) return null;
  return (width: info.width, height: info.height);
}
