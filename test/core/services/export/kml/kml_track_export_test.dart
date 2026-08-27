import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/kml/kml_export_service.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';

GpsTrack _track({int tzOffsetMinutes = 0, String? name}) {
  final startSec = DateTime.utc(2026, 5, 22, 8).millisecondsSinceEpoch ~/ 1000;
  return GpsTrack(
    id: 'track-1',
    startTime: startSec * 1000,
    endTime: (startSec + 60) * 1000,
    tzOffsetMinutes: tzOffsetMinutes,
    name: name,
    pointCount: 2,
    points: [
      GpsTrackPoint(timestamp: startSec, latitude: 20.5, longitude: -87.25),
      GpsTrackPoint(
        timestamp: startSec + 60,
        latitude: 20.51,
        longitude: -87.26,
      ),
    ],
  );
}

void main() {
  late KmlExportService service;

  setUp(() => service = KmlExportService());

  test('declares the gx namespace', () async {
    final kml = await service.generateTrackKml(_track());
    expect(kml, contains('xmlns:gx="http://www.google.com/kml/ext/2.2"'));
  });

  test('emits matching counts of when and gx:coord', () async {
    final kml = await service.generateTrackKml(_track());
    expect('<when>'.allMatches(kml).length, 2);
    expect('<gx:coord>'.allMatches(kml).length, 2);
  });

  test('writes gx:coord as lon lat alt, not lat lon', () async {
    final kml = await service.generateTrackKml(_track());
    // Longitude first. Reversed, this Cozumel track lands off Somalia.
    expect(kml, contains('<gx:coord>-87.25 20.5 0</gx:coord>'));
  });

  test('converts wall-clock timestamps back to real UTC', () async {
    final kml = await service.generateTrackKml(_track(tzOffsetMinutes: -300));
    expect(kml, contains('<when>2026-05-22T13:00:00Z</when>'));
  });

  test('includes an escaped track name when set', () async {
    final kml = await service.generateTrackKml(_track(name: 'Reef & Wall'));
    expect(kml, contains('Reef &amp; Wall'));
  });

  test('produces an empty gx:Track for a track with no points', () async {
    const empty = GpsTrack(id: 'e', startTime: 0, endTime: 1);
    final kml = await service.generateTrackKml(empty);
    expect(kml, contains('<gx:Track>'));
    expect(kml, isNot(contains('<when>')));
  });
}
