import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gps_log/data/services/track_import/gpx_track_parser.dart';
import 'package:submersion/features/gps_log/data/services/track_import/parsed_track.dart';

String _fixture(String name) =>
    File('test/fixtures/gps_tracks/$name').readAsStringSync();

void main() {
  test('parses every trkpt', () {
    expect(parseGpx(_fixture('sample.gpx')).fixes.length, 3);
  });

  test('reads the track name', () {
    expect(parseGpx(_fixture('sample.gpx')).name, 'Cozumel Day 3');
  });

  test('prefers the track name over the file title in metadata', () {
    // <metadata><name> comes first in document order, so a bare
    // findAllElements('name').first named every Garmin export the same.
    const xml = '''
<gpx version="1.1">
  <metadata><name>Garmin Connect Export</name></metadata>
  <trk>
    <name>Palancar Gardens</name>
    <trkseg>
      <trkpt lat="20.5" lon="-87.25"><time>2026-05-22T13:00:00Z</time></trkpt>
      <trkpt lat="20.6" lon="-87.26"><time>2026-05-22T13:01:00Z</time></trkpt>
    </trkseg>
  </trk>
</gpx>''';
    expect(parseGpx(xml).name, 'Palancar Gardens');
  });

  test('falls back to the file title when the track is unnamed', () {
    const xml = '''
<gpx version="1.1">
  <metadata><name>Garmin Connect Export</name></metadata>
  <trk><trkseg>
    <trkpt lat="20.5" lon="-87.25"><time>2026-05-22T13:00:00Z</time></trkpt>
  </trkseg></trk>
</gpx>''';
    expect(parseGpx(xml).name, 'Garmin Connect Export');
  });

  test('reads coordinates from the attributes', () {
    final first = parseGpx(_fixture('sample.gpx')).fixes.first;
    expect(first.lat, closeTo(20.5, 1e-9));
    expect(first.lon, closeTo(-87.25, 1e-9));
  });

  test('parses time as real UTC, not local', () {
    final first = parseGpx(_fixture('sample.gpx')).fixes.first;
    expect(first.utc.isUtc, isTrue);
    expect(first.utc, DateTime.utc(2026, 5, 22, 13));
  });

  test('reads hdop into accuracy where present', () {
    final fixes = parseGpx(_fixture('sample.gpx')).fixes;
    expect(fixes[0].accuracy, closeTo(5.0, 1e-9));
    expect(fixes[1].accuracy, isNull);
  });

  test('flattens multiple track segments into one ordered list', () {
    final track = parseGpx(_fixture('multi_seg.gpx'));
    expect(track.fixes.length, 4);
    final times = track.fixes.map((f) => f.utc.millisecondsSinceEpoch).toList();
    expect(times, orderedEquals([...times]..sort()));
  });

  test('rejects a file with no per-point timestamps', () {
    expect(
      () => parseGpx(_fixture('no_time.gpx')),
      throwsA(isA<TrackParseException>()),
    );
  });

  test('rejects a file with no track points at all', () {
    expect(
      () => parseGpx('<gpx version="1.1"><trk><trkseg/></trk></gpx>'),
      throwsA(isA<TrackParseException>()),
    );
  });

  test('rejects malformed XML with a TrackParseException, not a raw throw', () {
    expect(() => parseGpx('<gpx><trk>'), throwsA(isA<TrackParseException>()));
  });

  test('rejects a trkpt with out-of-range coordinates', () {
    const bad =
        '<gpx version="1.1"><trk><trkseg>'
        '<trkpt lat="200.0" lon="-87.0"><time>2026-05-22T13:00:00Z</time>'
        '</trkpt></trkseg></trk></gpx>';
    expect(() => parseGpx(bad), throwsA(isA<TrackParseException>()));
  });

  test('rejects a trkpt with an unparseable time', () {
    const bad =
        '<gpx version="1.1"><trk><trkseg>'
        '<trkpt lat="20.0" lon="-87.0"><time>yesterday</time>'
        '</trkpt></trkseg></trk></gpx>';
    expect(() => parseGpx(bad), throwsA(isA<TrackParseException>()));
  });
}
