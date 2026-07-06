import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'entities/gps_track.dart';

/// Encodes points as a gzipped JSON array of
/// [wallClockEpochSeconds, lat, lon, accuracyMeters] tuples.
Uint8List encodeTrackPoints(List<GpsTrackPoint> points) {
  final json = jsonEncode([
    for (final p in points) [p.timestamp, p.latitude, p.longitude, p.accuracy],
  ]);
  return Uint8List.fromList(gzip.encode(utf8.encode(json)));
}

List<GpsTrackPoint> decodeTrackPoints(Uint8List blob) {
  final json = utf8.decode(gzip.decode(blob));
  final list = jsonDecode(json) as List<dynamic>;
  return [
    for (final raw in list)
      GpsTrackPoint(
        timestamp: (raw[0] as num).toInt(),
        latitude: (raw[1] as num).toDouble(),
        longitude: (raw[2] as num).toDouble(),
        accuracy: raw[3] == null ? null : (raw[3] as num).toDouble(),
      ),
  ];
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
