/// A video track's path, packed into one column (issue #4675).
///
/// Byte 0 is the layout version. Then, for each sample, a little-endian
/// uint32 offset in milliseconds from the track's start, and the box's x,
/// y, width and height, each a little-endian uint16 of the value times
/// 65535: twelve bytes a sample.
library;

import 'dart:typed_data';

import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/track_sample.dart';

const int _version = 1;
const int _sampleBytes = 12;
const int _scale = 65535;

Uint8List encodeTrackPath(int startMs, List<TrackSample> samples) {
  final data = ByteData(1 + samples.length * _sampleBytes)
    ..setUint8(0, _version);
  var at = 1;
  for (final sample in samples) {
    data.setUint32(at, sample.ms - startMs, Endian.little);
    final box = sample.box;
    for (final (k, value) in [box.x, box.y, box.width, box.height].indexed) {
      data.setUint16(at + 4 + k * 2, _unit(value), Endian.little);
    }
    at += _sampleBytes;
  }
  return data.buffer.asUint8List();
}

/// Throws [FormatException] for a version it does not know or a length
/// that is not whole samples.
List<TrackSample> decodeTrackPath(int startMs, Uint8List bytes) {
  if (bytes.isEmpty || bytes[0] != _version) {
    throw const FormatException('Unknown track path version');
  }
  if ((bytes.length - 1) % _sampleBytes != 0) {
    throw const FormatException('Track path is not whole samples');
  }
  final data = ByteData.sublistView(bytes);
  double read(int offset) => data.getUint16(offset, Endian.little) / _scale;
  return [
    for (var at = 1; at < bytes.length; at += _sampleBytes)
      TrackSample(
        ms: startMs + data.getUint32(at, Endian.little),
        box: IdentificationBox(
          x: read(at + 4),
          y: read(at + 6),
          width: read(at + 8),
          height: read(at + 10),
        ),
      ),
  ];
}

int _unit(double value) => (value.clamp(0.0, 1.0) * _scale).round();
