/// JPEG marker-segment walking shared by the dimensions and EXIF readers.
///
/// A JPEG is SOI followed by marker segments, each `[0xFF][marker][length:2]`
/// with a length that counts itself but not the marker. What the readers
/// want sits ahead of the first SOS: the frame header always does, and EXIF
/// must (the Exif spec puts its APP1 directly after SOI). Other APPn blocks
/// may legally sit between the scans of a multi-scan JPEG, so this walker
/// does not see those. Past the SOS lies the entropy-coded scan, which is
/// most of the file. The walker seeks from segment to segment, so it touches
/// a few KB of a multi-MB photo.
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

/// How many segments one walk will step through before the scan. A camera
/// JPEG carries a few dozen (APPn blocks, tables, the frame header), and even
/// an ICC profile split across 64 KB APP2 chunks stays far below this; a file
/// of thousands of tiny segments is crafted or corrupt.
const _maxSegments = 1024;

/// Lazily yields the segments ahead of the scan, in file order.
///
/// Stray bytes where a marker should begin (anything but `0xFF`, or a
/// stuffed `0xFF00`) are skipped up to the next `0xFF`, as libjpeg does and as
/// `package:image`'s `decodeJpgExif` did before this walker replaced it, so a
/// photo with junk between segments keeps its EXIF and frame header.
///
/// A segment whose length runs past EOF is yielded cut to the bytes that
/// exist, so its [JpegSegment.length] can be shorter than the declared one,
/// and is the last segment yielded.
///
/// Stops without error at the SOS (start of scan) or EOI marker, and at
/// corruption it cannot step past: a missing SOI, more than [_maxResyncBytes]
/// of stray bytes, fill bytes and standalone markers in all, more than
/// [_maxSegments] segments, or a length shorter than its own field. Callers
/// therefore read "the walk ended" as "not found".
Iterable<JpegSegment> jpegHeaderSegments(RandomAccessFile raf, int end) sync* {
  if (end < 4) return;
  final soi = readBytesAt(raf, 0, 2);
  if (soi.length < 2 || soi[0] != 0xff || soi[1] != 0xd8) return;

  var pos = 2;
  var resyncBudget = _maxResyncBytes;
  var segments = 0;
  while (pos + 2 <= end) {
    // The marker and, for a length-bearing segment, its length field, in
    // one read.
    final head = readBytesAt(raf, pos, 4);
    if (head.length < 2) return;
    // 0xFF00 is a stuffed data byte, which cannot appear between segments:
    // like any other non-marker byte, it is junk to step over.
    if (head[0] != 0xff || head[1] == 0x00) {
      // Every skipped byte is charged, the one at [pos] included, so junk
      // found one byte before a marker still draws on the budget.
      final next = _nextMarkerByte(
        raf,
        pos + 1,
        min(end, pos + 1 + resyncBudget),
      );
      if (next == null) return;
      resyncBudget -= next - pos;
      pos = next;
      continue;
    }
    final marker = head[1];

    // A marker may be preceded by any number of 0xFF fill bytes. They draw on
    // the same budget as junk, or a file padded with 0xFF would be walked to
    // EOF a byte at a time.
    if (marker == 0xff) {
      // Step over the whole run this read saw, to its last 0xFF, which may
      // be the one that opens the marker.
      var run = 2;
      while (run < head.length && head[run] == 0xff) {
        run++;
      }
      resyncBudget -= run - 1;
      if (resyncBudget < 0) return;
      pos += run - 1;
      continue;
    }
    // Standalone markers carry no length payload: TEM, SOI, RSTn. None
    // belongs between header segments, so they draw on the budget too.
    if (marker == 0x01 ||
        marker == 0xd8 ||
        (marker >= 0xd0 && marker <= 0xd7)) {
      resyncBudget -= 2;
      if (resyncBudget < 0) return;
      pos += 2;
      continue;
    }
    // EOI, or the start of the scan. Everything past an SOS is entropy-coded
    // data, and stepping through it is exactly the cost being avoided.
    if (marker == 0xd9 || marker == 0xda) return;

    if (head.length < 4) return;
    final length = beU16(head, 2);
    // A segment shorter than its own length field is corrupt.
    if (length < 2) return;
    if (++segments > _maxSegments) return;

    final start = pos + 4;
    // A segment running past EOF was cut short (an interrupted copy, say).
    // What survives of it is yielded, as `decodeJpgExif` parsed a clamped
    // block, so an EXIF segment cut after its date still has one; nothing
    // can follow it, so the walk ends there.
    if (pos + 2 + length > end) {
      if (end > start) {
        yield (marker: marker, start: start, length: end - start);
      }
      return;
    }
    yield (marker: marker, start: start, length: length - 2);
    pos += 2 + length;
  }
}

/// The position of the first `0xFF` in [from, limit), or null when there is
/// none.
///
/// The first read is small because real junk is a byte or two, and a file of
/// many short gaps would otherwise read a full chunk per gap; longer gaps
/// widen to 512-byte reads.
int? _nextMarkerByte(RandomAccessFile raf, int from, int limit) {
  var chunk = 16;
  for (var pos = from; pos < limit; pos += chunk, chunk = 512) {
    final bytes = readBytesAt(raf, pos, min(chunk, limit - pos));
    if (bytes.isEmpty) return null;
    final i = bytes.indexOf(0xff);
    if (i >= 0) return pos + i;
  }
  return null;
}
