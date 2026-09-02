import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:submersion/core/utils/bounded_inflate.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';

/// Thrown when a track points blob cannot be decoded, or when a track is too
/// large to encode.
///
/// One declared type, because the alternative was whatever the first failing
/// positional cast happened to raise: a `_TypeError` for a wrong element
/// type, a `RangeError` for a short tuple. `_TypeError` is private, so a
/// caller could not even name it in an `on` clause, and every read of a
/// synced blob had to either catch everything or catch nothing.
class TrackPointCodecException implements Exception {
  const TrackPointCodecException(this.message);

  final String message;

  @override
  String toString() => 'TrackPointCodecException: $message';
}

/// The largest number of points this codec will write or read.
///
/// 262,144 is over 72 hours of one-hertz fixes, where a recorded track uses
/// a 20 m distance filter and the longest imported day this app has seen is
/// nearer 21,000. The cap is not a claim about plausible tracks but a bound
/// on allocation: decoding materialises the parsed JSON tuples and the
/// [GpsTrackPoint] objects at the same time, so an uncapped count sizes an
/// object graph directly from peer-supplied bytes.
///
/// Encode enforces the same cap. A blob this codec would refuse to read must
/// never be written, or an oversized import would persist as a track whose
/// points can never be loaded back.
const int kMaxTrackPointCount = 1 << 18;

/// The largest uncompressed body this codec will inflate.
///
/// The outer bound against unbounded inflation, not the binding guard:
/// [kMaxTrackPointCount] tuples of full-precision JSON come to roughly 17 MB,
/// so this leaves headroom rather than sitting on the real limit. It still
/// has to exist, because the point cap can only be checked after the body is
/// already in memory.
const int kMaxTrackBodyBytes = 32 * 1024 * 1024;

/// The largest compressed blob this codec will accept.
///
/// Equal to [kMaxTrackBodyBytes], which is a margin rather than an identity.
/// gzip can emit slightly more than it was given, so a maximal incompressible
/// body really would produce a blob a little over this cap and be refused.
/// Nothing legitimate reaches that: [kMaxTrackPointCount] binds first, at
/// roughly 17 MB of body for a maximal track, and JSON of numeric tuples
/// compresses rather than expanding, so the two caps are nowhere near meeting.
///
/// The cap earns its place regardless of where it sits. Bytes appended after
/// a complete gzip stream are copied whole into the native filter and then
/// silently discarded: a spike with no output to show for it.
const int kMaxTrackBlobBytes = kMaxTrackBodyBytes;

/// The largest number of commas this codec will accept in an inflated body.
///
/// [kMaxTrackBodyBytes] bounds the bytes but NOT the object graph jsonDecode
/// builds from them, and the point cap can only be checked once that graph
/// exists. 32 MiB of the densest legal tuple, `[0,0,0,0]`, is 3.35 million of
/// them: measured, jsonDecode alone took RSS from 258 MB to 630 MB before any
/// count was looked at. A flat array of scalars costs much the same.
///
/// Commas give a bound that can be had from the raw bytes. For any JSON array
/// `elementCount <= commaCount + 1`, and this encoder writes exactly
/// `4N - 1` commas for N points, so a legitimate maximal track sits one comma
/// under this cap and cannot be refused. Nesting or strings in a hostile body
/// only add commas, which makes the check stricter, never weaker.
const int kMaxTrackBodyCommas = 4 * kMaxTrackPointCount;

/// Encodes points as a gzipped JSON array of
/// [wallClockEpochSeconds, lat, lon, accuracyMeters] tuples.
///
/// Throws [TrackPointCodecException] if [points] is longer than
/// [kMaxTrackPointCount].
Uint8List encodeTrackPoints(List<GpsTrackPoint> points) {
  if (points.length > kMaxTrackPointCount) {
    throw TrackPointCodecException(
      'track of ${points.length} point(s) exceeds the '
      '$kMaxTrackPointCount this codec can read back',
    );
  }
  final json = jsonEncode([
    for (final p in points) [p.timestamp, p.latitude, p.longitude, p.accuracy],
  ]);
  return Uint8List.fromList(gzip.encode(utf8.encode(json)));
}

/// Decodes a blob written by [encodeTrackPoints].
///
/// The blob is peer-supplied: `gpsTracks` is a synced entity and its points
/// column rides through sync as base64, so a remote device's bytes are
/// written verbatim and inflated here. Everything is therefore bounded
/// before it is allocated and shape-checked before it is cast.
///
/// Throws [TrackPointCodecException] for every malformed input, including an
/// oversized blob, a body that inflates past [kMaxTrackBodyBytes], more than
/// [kMaxTrackPointCount] points, and any tuple that is not four finite
/// numbers with an optional null accuracy.
List<GpsTrackPoint> decodeTrackPoints(Uint8List blob) {
  final Uint8List body;
  try {
    body = inflateBounded(
      blob,
      decoder: gzip.decoder,
      maxBytes: kMaxTrackBodyBytes,
      maxBlobBytes: kMaxTrackBlobBytes,
    );
  } on BoundedInflateException catch (e) {
    throw TrackPointCodecException(e.message);
  }

  // Before the parse, not after: this is the only bound on what jsonDecode
  // is about to allocate. Counted over the bytes, which is exact for UTF-8
  // (no continuation byte is below 0x80) and saves decoding a body that is
  // going to be refused anyway.
  final commas = _countCommas(body);
  if (commas > kMaxTrackBodyCommas) {
    throw TrackPointCodecException(
      'body has $commas comma(s), over the $kMaxTrackBodyCommas allowed',
    );
  }

  // Decoded in two steps so the message names the failure that happened.
  // Folding them together reported a truncated gzip body, which fails as
  // bytes, as though it were bad JSON, which is the wrong thing to go
  // looking for in a log.
  final String text;
  try {
    text = utf8.decode(body);
  } on FormatException catch (e) {
    throw TrackPointCodecException('body is not UTF-8: ${e.message}');
  }

  final dynamic decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException catch (e) {
    throw TrackPointCodecException('not track point JSON: ${e.message}');
  }

  if (decoded is! List) {
    throw TrackPointCodecException(
      'expected a JSON array, got ${decoded.runtimeType}',
    );
  }
  if (decoded.length > kMaxTrackPointCount) {
    throw TrackPointCodecException(
      'blob declares ${decoded.length} point(s), over the '
      '$kMaxTrackPointCount allowed',
    );
  }

  final points = <GpsTrackPoint>[];
  for (var i = 0; i < decoded.length; i++) {
    final raw = decoded[i];
    if (raw is! List || raw.length != 4) {
      throw TrackPointCodecException('point $i is not a four-element tuple');
    }
    final rawAccuracy = raw[3];
    points.add(
      GpsTrackPoint(
        timestamp: _requireFinite(raw[0], i, 'timestamp').toInt(),
        latitude: _requireFinite(raw[1], i, 'latitude').toDouble(),
        longitude: _requireFinite(raw[2], i, 'longitude').toDouble(),
        // Null is the only non-numeric accuracy the encoder writes.
        accuracy: rawAccuracy == null
            ? null
            : _requireFinite(rawAccuracy, i, 'accuracy').toDouble(),
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

/// Returns [value] as a finite number, or throws naming the offending field.
///
/// Finiteness is not pedantry: JSON has no infinity literal, but an
/// out-of-range exponent such as `1e999` parses to `Infinity`, and
/// `toInt()` on an infinity throws an `UnsupportedError` that no call site
/// is written to expect.
///
/// The two rejections are reported apart because only one of them can safely
/// name what it saw. [value] is peer-supplied and nothing upstream bounds a
/// single element: a 20 MB string carries only three commas, so it clears
/// both the body cap and the comma cap, and interpolating it was measured
/// building a 20,971,556 character message that the repository then logged
/// whole. A type name says as much and cannot grow.
num _requireFinite(Object? value, int index, String field) {
  if (value is! num) {
    throw TrackPointCodecException(
      'point $index has a non-numeric $field: ${value.runtimeType}',
    );
  }
  if (!value.isFinite) {
    // Safe to print: a non-finite num is NaN or an infinity, never long.
    throw TrackPointCodecException(
      'point $index has a non-finite $field: $value',
    );
  }
  return value;
}

/// Converts a real-UTC instant to the app's wall-clock-as-UTC epoch seconds:
/// the device's local wall-clock components reinterpreted as UTC. This is
/// the same convention dive computers' clocks follow, so track points line
/// up with dives.entryTime with no conversion at match time.
int toWallClockEpochSeconds(DateTime timestamp) {
  final local = timestamp.toLocal();
  return DateTime.utc(
        local.year,
        local.month,
        local.day,
        local.hour,
        local.minute,
        local.second,
      ).millisecondsSinceEpoch ~/
      1000;
}
