import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:submersion/core/utils/bounded_inflate.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';

/// Thrown when a route points blob cannot be decoded, or when a route is
/// too large to encode. Mirrors `TrackPointCodecException` in the GPS
/// logger: one declared type, so a caller can name what a bad blob raises
/// instead of catching everything or nothing.
class NavTrackCodecException implements Exception {
  const NavTrackCodecException(this.message);

  final String message;

  @override
  String toString() => 'NavTrackCodecException: $message';
}

/// The largest number of samples this codec will write or read.
///
/// 131,072 (1 << 17) is over 36 hours of one-hertz samples, an order of
/// magnitude beyond any real dive, while still bounding allocation from
/// peer-supplied bytes: decoding materialises the parsed JSON tuples and
/// the [NavTrackPoint] objects at the same time, so an uncapped count sizes
/// an object graph directly from bytes a sync peer supplied.
///
/// Encode enforces the same cap. A blob this codec would refuse to read
/// must never be written, or an oversized import would persist as a route
/// whose samples can never be loaded back.
const int kMaxNavTrackPointCount = 1 << 17;

/// The largest uncompressed body this codec will inflate.
///
/// The outer bound against unbounded inflation, not the binding guard:
/// [kMaxNavTrackPointCount] tuples of full-precision, eleven-field JSON
/// come to well under this, so it leaves headroom rather than sitting on
/// the real limit. It still has to exist, because the sample cap can only
/// be checked after the body is already in memory.
const int kMaxNavTrackBodyBytes = 32 * 1024 * 1024;

/// The largest compressed blob this codec will accept.
///
/// Equal to [kMaxNavTrackBodyBytes]: gzip can emit slightly more than it
/// was given, so a maximal incompressible body could produce a blob a
/// little over this cap and would otherwise be refused for the wrong
/// reason. Bytes appended after a complete gzip stream are copied whole
/// into the native filter and then silently discarded, so this cap earns
/// its place regardless of where it sits.
const int kMaxNavTrackBlobBytes = kMaxNavTrackBodyBytes;

/// The largest number of commas this codec will accept in an inflated
/// body.
///
/// [kMaxNavTrackBodyBytes] bounds the bytes but not the object graph
/// `jsonDecode` builds from them, and the sample cap can only be checked
/// once that graph exists. Commas give a bound that can be had from the raw
/// bytes before that allocation: for any JSON array,
/// `elementCount <= commaCount + 1`, and this encoder writes exactly
/// `10N` commas for N eleven-field tuples (9 inside each tuple, 1 between
/// tuples, none after the last), so a legitimate maximal route sits under
/// this cap and is never wrongly refused.
const int kMaxNavTrackBodyCommas = 10 * kMaxNavTrackPointCount;

/// Encodes [points] as a gzipped JSON array of
/// `[wallClockEpochSeconds, north, east, depth, course, pitch, roll,
///  distance, speed, temperature, batteryVolts]` tuples, in order.
/// Optional fields that are null on the point are written as `null`.
///
/// Throws [NavTrackCodecException] if [points] is longer than
/// [kMaxNavTrackPointCount].
Uint8List encodeNavTrackPoints(List<NavTrackPoint> points) {
  if (points.length > kMaxNavTrackPointCount) {
    throw NavTrackCodecException(
      'route of ${points.length} sample(s) exceeds the '
      '$kMaxNavTrackPointCount this codec can read back',
    );
  }
  final json = jsonEncode([
    for (final p in points)
      [
        p.timestamp,
        p.north,
        p.east,
        p.depth,
        p.course,
        p.pitch,
        p.roll,
        p.distance,
        p.speed,
        p.temperature,
        p.batteryVolts,
      ],
  ]);
  return Uint8List.fromList(gzip.encode(utf8.encode(json)));
}

/// Decodes a blob written by [encodeNavTrackPoints].
///
/// The blob is peer-supplied: `nav_tracks` is a synced entity and its
/// points column rides through sync as base64, so a remote device's bytes
/// are written verbatim and inflated here. Everything is bounded before it
/// is allocated and shape-checked before it is cast, mirroring
/// `decodeTrackPoints` in the GPS logger.
///
/// Throws [NavTrackCodecException] for every malformed input, including an
/// oversized blob, a body that inflates past [kMaxNavTrackBodyBytes], more
/// than [kMaxNavTrackPointCount] samples, and any tuple that is not eleven
/// elements with the first four (timestamp, north, east, depth) finite
/// numbers and the rest either a finite number or null.
List<NavTrackPoint> decodeNavTrackPoints(Uint8List blob) {
  final Uint8List body;
  try {
    body = inflateBounded(
      blob,
      decoder: gzip.decoder,
      maxBytes: kMaxNavTrackBodyBytes,
      maxBlobBytes: kMaxNavTrackBlobBytes,
    );
  } on BoundedInflateException catch (e) {
    throw NavTrackCodecException(e.message);
  }

  // Before the parse, not after: the only bound on what jsonDecode is
  // about to allocate. Counted over the bytes, exact for UTF-8 (no
  // continuation byte is below 0x80), and saves decoding a body that is
  // going to be refused anyway.
  final commas = _countCommas(body);
  if (commas > kMaxNavTrackBodyCommas) {
    throw NavTrackCodecException(
      'body has $commas comma(s), over the $kMaxNavTrackBodyCommas allowed',
    );
  }

  // Decoded in two steps so the message names the failure that happened:
  // a truncated gzip body fails as bytes, not as bad JSON.
  final String text;
  try {
    text = utf8.decode(body);
  } on FormatException catch (e) {
    throw NavTrackCodecException('body is not UTF-8: ${e.message}');
  }

  final dynamic decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException catch (e) {
    throw NavTrackCodecException('not route point JSON: ${e.message}');
  }

  if (decoded is! List) {
    throw NavTrackCodecException(
      'expected a JSON array, got ${decoded.runtimeType}',
    );
  }
  if (decoded.length > kMaxNavTrackPointCount) {
    throw NavTrackCodecException(
      'blob declares ${decoded.length} sample(s), over the '
      '$kMaxNavTrackPointCount allowed',
    );
  }

  final points = <NavTrackPoint>[];
  for (var i = 0; i < decoded.length; i++) {
    final raw = decoded[i];
    if (raw is! List || raw.length != 11) {
      throw NavTrackCodecException('sample $i is not an eleven-element tuple');
    }
    points.add(
      NavTrackPoint(
        timestamp: _requireFinite(raw[0], i, 'timestamp').toInt(),
        north: _requireFinite(raw[1], i, 'north').toDouble(),
        east: _requireFinite(raw[2], i, 'east').toDouble(),
        depth: _requireFinite(raw[3], i, 'depth').toDouble(),
        course: _optionalFinite(raw[4], i, 'course'),
        pitch: _optionalFinite(raw[5], i, 'pitch'),
        roll: _optionalFinite(raw[6], i, 'roll'),
        distance: _optionalFinite(raw[7], i, 'distance'),
        speed: _optionalFinite(raw[8], i, 'speed'),
        temperature: _optionalFinite(raw[9], i, 'temperature'),
        batteryVolts: _optionalFinite(raw[10], i, 'batteryVolts'),
      ),
    );
  }
  return points;
}

/// Counts the 0x2C bytes in [body].
int _countCommas(Uint8List body) {
  var count = 0;
  for (var i = 0; i < body.length; i++) {
    if (body[i] == 0x2C) count++;
  }
  return count;
}

/// Returns [value] as a finite number, or throws naming the offending
/// field. Finiteness matters because JSON has no infinity literal, but an
/// out-of-range exponent such as `1e999` parses to `Infinity`, and
/// `toInt()`/`toDouble()` on one is not a mistake this codec should let a
/// caller stumble into downstream.
num _requireFinite(Object? value, int index, String field) {
  if (value is! num) {
    throw NavTrackCodecException(
      'sample $index has a non-numeric $field: ${value.runtimeType}',
    );
  }
  if (!value.isFinite) {
    // Safe to print: a non-finite num is NaN or an infinity, never long.
    throw NavTrackCodecException(
      'sample $index has a non-finite $field: $value',
    );
  }
  return value;
}

/// Like [_requireFinite], but null is the only other value the encoder
/// ever writes for an optional field.
double? _optionalFinite(Object? value, int index, String field) {
  if (value == null) return null;
  return _requireFinite(value, index, field).toDouble();
}
