/// JPEG marker-segment walking shared by the dimensions and EXIF readers.
///
/// A JPEG is SOI followed by marker segments, each `[0xFF][marker][length:2]`
/// with a length that counts itself but not the marker. Everything a metadata
/// reader wants (APPn blocks, the frame header) sits ahead of the first SOS;
/// past it lies the entropy-coded scan, which is most of the file. The walker
/// seeks from segment to segment, so it touches a few KB of a multi-MB photo.
library;

import 'dart:io';
import 'dart:math';

import 'package:submersion/features/media/data/services/isobmff_boxes.dart';

/// One length-bearing segment: its [marker] byte and the file range of its
/// payload, which starts just past the 2-byte length field.
typedef JpegSegment = ({int marker, int start, int length});

/// How many stray bytes one walk will step over, across every gap, looking
/// for the next marker. Real junk between segments is a byte or two from a
/// sloppy writer; the budget keeps a file that only starts like a JPEG from
/// turning the walk into a scan of the whole file, however its junk is
/// spread.
const _maxResyncBytes = 64 * 1024;

/// Lazily yields the segments ahead of the scan, in file order.
///
/// Stray bytes where a marker should begin (anything but `0xFF`, or a
/// stuffed `0xFF00`) are skipped up to the next `0xFF`, as libjpeg does and as
/// `package:image`'s `decodeJpgExif` did before this walker replaced it, so a
/// photo with junk between segments keeps its EXIF and frame header.
///
/// Stops without error at the SOS (start of scan) or EOI marker, and at
/// corruption it cannot step past: a missing SOI, more than [_maxResyncBytes]
/// of stray bytes in all, or a length that is shorter than its own
/// field or runs past EOF. Callers therefore read "the walk ended" as "not
/// found".
Iterable<JpegSegment> jpegHeaderSegments(RandomAccessFile raf, int end) sync* {
  if (end < 4) return;
  final soi = readBytesAt(raf, 0, 2);
  if (soi.length < 2 || soi[0] != 0xff || soi[1] != 0xd8) return;

  var pos = 2;
  var resyncBudget = _maxResyncBytes;
  while (pos + 2 <= end) {
    final head = readBytesAt(raf, pos, 2);
    if (head.length < 2) return;
    // 0xFF00 is a stuffed data byte, which cannot appear between segments:
    // like any other non-marker byte, it is junk to step over.
    if (head[0] != 0xff || head[1] == 0x00) {
      final from = pos + 1;
      final next = _nextMarkerByte(raf, from, min(end, from + resyncBudget));
      if (next == null) return;
      resyncBudget -= next - from;
      pos = next;
      continue;
    }
    final marker = head[1];
    pos += 2;

    // A marker may be preceded by any number of 0xFF fill bytes.
    if (marker == 0xff) {
      pos -= 1;
      continue;
    }
    // Standalone markers carry no length payload: TEM, SOI, RSTn.
    if (marker == 0x01 ||
        marker == 0xd8 ||
        (marker >= 0xd0 && marker <= 0xd7)) {
      continue;
    }
    // EOI, or the start of the scan. Everything past an SOS is entropy-coded
    // data, and stepping through it is exactly the cost being avoided.
    if (marker == 0xd9 || marker == 0xda) return;

    if (pos + 2 > end) return;
    final length = beU16(readBytesAt(raf, pos, 2), 0);
    // A segment shorter than its own length field, or one running past EOF,
    // is corrupt.
    if (length < 2 || pos + length > end) return;

    yield (marker: marker, start: pos + 2, length: length - 2);
    pos += length;
  }
}

/// The position of the first `0xFF` in [from, limit), or null when there is
/// none.
int? _nextMarkerByte(RandomAccessFile raf, int from, int limit) {
  const chunk = 512;
  for (var pos = from; pos < limit; pos += chunk) {
    final bytes = readBytesAt(raf, pos, min(chunk, limit - pos));
    if (bytes.isEmpty) return null;
    final i = bytes.indexOf(0xff);
    if (i >= 0) return pos + i;
  }
  return null;
}
