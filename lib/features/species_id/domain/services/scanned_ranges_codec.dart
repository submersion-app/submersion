/// The stretches of a video already scanned, packed into one column
/// (issue #4709).
///
/// Byte 0 is the layout version. Then, for each stretch, its start and its
/// end in milliseconds, each a little-endian uint32: eight bytes a stretch.
library;

import 'dart:typed_data';

import 'package:submersion/features/species_id/domain/entities/scanned_ranges.dart';

const int _version = 1;
const int _stretchBytes = 8;

Uint8List encodeScannedRanges(ScannedRanges ranges) {
  final stretches = ranges.stretches;
  final data = ByteData(1 + stretches.length * _stretchBytes)
    ..setUint8(0, _version);
  var at = 1;
  for (final s in stretches) {
    data
      ..setUint32(at, s.startMs, Endian.little)
      ..setUint32(at + 4, s.endMs, Endian.little);
    at += _stretchBytes;
  }
  return data.buffer.asUint8List();
}

/// Throws [FormatException] for a version it does not know, a length that
/// is not whole stretches, or a stretch that does not end after it starts.
ScannedRanges decodeScannedRanges(Uint8List bytes) {
  if (bytes.isEmpty || bytes[0] != _version) {
    throw const FormatException('Unknown scanned ranges version');
  }
  if ((bytes.length - 1) % _stretchBytes != 0) {
    throw const FormatException('Scanned ranges are not whole stretches');
  }
  final data = ByteData.sublistView(bytes);
  var ranges = const ScannedRanges();
  for (var at = 1; at < bytes.length; at += _stretchBytes) {
    final start = data.getUint32(at, Endian.little);
    final end = data.getUint32(at + 4, Endian.little);
    if (end <= start) {
      throw const FormatException('A scanned stretch ends before it starts');
    }
    ranges = ranges.add(start, end);
  }
  return ranges;
}
