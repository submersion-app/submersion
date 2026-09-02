/// ISO-BMFF / QuickTime box walking shared by the capture-time, EXIF, and
/// GPS readers. A box is [size:uint32][type:4 ascii][payload]; size == 1
/// means a 64-bit size follows the type; size == 0 means "to end of range".
///
/// The file walkers seek, so a multi-GB clip whose `moov` sits after `mdat`
/// is walked without ever reading the media payload.
library;

import 'dart:io';
import 'dart:typed_data';

/// Half-open byte range [start, end) of a box's content (payload).
class BoxRange {
  const BoxRange(this.start, this.end);
  final int start;
  final int end;
  int get length => end - start;
}

/// Returns the content range of the first sibling box of [type] within
/// [start, end), or null.
BoxRange? findBox(RandomAccessFile raf, int start, int end, String type) {
  for (final r in _walk(raf, start, end)) {
    if (r.type == type) return r.range;
  }
  return null;
}

/// Every sibling box of [type] within [start, end), in file order.
List<BoxRange> findBoxes(
  RandomAccessFile raf,
  int start,
  int end,
  String type,
) => [
  for (final r in _walk(raf, start, end))
    if (r.type == type) r.range,
];

/// Byte-buffer twin of [findBox], for sub-boxes already read into memory.
BoxRange? findBoxInBytes(Uint8List b, int start, int end, String type) {
  for (final r in _walkBytes(b, start, end)) {
    if (r.type == type) return r.range;
  }
  return null;
}

/// Byte-buffer twin of [findBoxes].
List<BoxRange> findBoxesInBytes(Uint8List b, int start, int end, String type) =>
    [
      for (final r in _walkBytes(b, start, end))
        if (r.type == type) r.range,
    ];

/// A box's four-character type paired with its content range.
typedef BoxHeader = ({String type, BoxRange range});

/// Every sibling box within [start, end), in file order, whatever its type.
///
/// Callers that need a box's POSITION among its siblings need all of them,
/// not just the ones of one type: HEIC `ipma` property indices are 1-based
/// into `ipco`'s full child list, so skipping a `hvcC` shifts every later
/// index onto the wrong property.
List<BoxHeader> boxesInBytes(Uint8List b, int start, int end) =>
    _walkBytes(b, start, end).toList();

/// Lazily yields sibling boxes; stops at the first corrupt header so a bad
/// size never walks past [end] or spins.
Iterable<BoxHeader> _walk(RandomAccessFile raf, int start, int end) sync* {
  var pos = start;
  while (pos + 8 <= end) {
    raf.setPositionSync(pos);
    final header = raf.readSync(8);
    if (header.length < 8) return;
    var size = beU32(header, 0);
    var headerLen = 8;
    if (size == 1) {
      final ext = raf.readSync(8);
      if (ext.length < 8) return;
      size = beU64(ext, 0);
      headerLen = 16;
    } else if (size == 0) {
      size = end - pos;
    }
    if (size < headerLen || pos + size > end) return;
    yield (
      type: String.fromCharCodes(header, 4, 8),
      range: BoxRange(pos + headerLen, pos + size),
    );
    pos += size;
  }
}

Iterable<BoxHeader> _walkBytes(Uint8List b, int start, int end) sync* {
  var pos = start;
  while (pos + 8 <= end) {
    var size = beU32(b, pos);
    var headerLen = 8;
    if (size == 1) {
      if (pos + 16 > end) return;
      size = beU64(b, pos + 8);
      headerLen = 16;
    } else if (size == 0) {
      size = end - pos;
    }
    if (size < headerLen || pos + size > end) return;
    yield (
      type: fourCC(b, pos + 4),
      range: BoxRange(pos + headerLen, pos + size),
    );
    pos += size;
  }
}

int beU16(Uint8List b, int o) => (b[o] << 8) | b[o + 1];

int beS16(Uint8List b, int o) => beU16(b, o).toSigned(16);

int beU32(Uint8List b, int o) =>
    (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3];

int beS32(Uint8List b, int o) => beU32(b, o).toSigned(32);

int beU64(Uint8List b, int o) => (beU32(b, o) << 32) | beU32(b, o + 4);

String fourCC(Uint8List b, int o) => String.fromCharCodes(b, o, o + 4);

int readByteAt(RandomAccessFile raf, int position) {
  raf.setPositionSync(position);
  return raf.readSync(1).first;
}

int readU32At(RandomAccessFile raf, int position) {
  raf.setPositionSync(position);
  return beU32(raf.readSync(4), 0);
}

int readU64At(RandomAccessFile raf, int position) {
  raf.setPositionSync(position);
  return beU64(raf.readSync(8), 0);
}

Uint8List readBytesAt(RandomAccessFile raf, int position, int length) {
  raf.setPositionSync(position);
  return raf.readSync(length);
}
