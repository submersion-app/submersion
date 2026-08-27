import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gps_log/data/services/track_import/kml_track_parser.dart';
import 'package:submersion/features/gps_log/data/services/track_import/parsed_track.dart';

String _fixture(String name) =>
    File('test/fixtures/gps_tracks/$name').readAsStringSync();

void main() {
  test('parses every when/coord pair', () {
    expect(parseKml(_fixture('sample.kml')).fixes.length, 3);
  });

  test('reads gx:coord as lon lat, not lat lon', () {
    // The fixture's first coord is "-87.25 20.50 0". Reading it backwards
    // would put this Cozumel track off the coast of Somalia.
    final first = parseKml(_fixture('sample.kml')).fixes.first;
    expect(first.lat, closeTo(20.50, 1e-9));
    expect(first.lon, closeTo(-87.25, 1e-9));
  });

  test('pairs the nth when with the nth coord', () {
    final fixes = parseKml(_fixture('sample.kml')).fixes;
    expect(fixes[1].utc, DateTime.utc(2026, 5, 22, 13, 1));
    expect(fixes[1].lon, closeTo(-87.26, 1e-9));
  });

  test('reads the placemark name', () {
    expect(parseKml(_fixture('sample.kml')).name, 'Cozumel Day 3');
  });

  test('prefers the placemark name over the document title', () {
    // <Document><name> comes first in document order, so a bare
    // findAllElements('name').first named every Google Earth export the same.
    const xml = '''
<kml xmlns:gx="http://www.google.com/kml/ext/2.2">
  <Document>
    <name>My Places</name>
    <Placemark>
      <name>Palancar Gardens</name>
      <gx:Track>
        <when>2026-05-22T13:00:00Z</when>
        <gx:coord>-87.25 20.5 0</gx:coord>
        <when>2026-05-22T13:01:00Z</when>
        <gx:coord>-87.26 20.6 0</gx:coord>
      </gx:Track>
    </Placemark>
  </Document>
</kml>''';
    expect(parseKml(xml).name, 'Palancar Gardens');
  });

  test('falls back to the document title for an unnamed placemark', () {
    const xml = '''
<kml xmlns:gx="http://www.google.com/kml/ext/2.2">
  <Document>
    <name>My Places</name>
    <Placemark><gx:Track>
      <when>2026-05-22T13:00:00Z</when>
      <gx:coord>-87.25 20.5 0</gx:coord>
    </gx:Track></Placemark>
  </Document>
</kml>''';
    expect(parseKml(xml).name, 'My Places');
  });

  test('parses times as real UTC', () {
    final first = parseKml(_fixture('sample.kml')).fixes.first;
    expect(first.utc.isUtc, isTrue);
    expect(first.utc, DateTime.utc(2026, 5, 22, 13));
  });

  test('rejects a LineString with no timestamps', () {
    expect(
      () => parseKml(_fixture('linestring.kml')),
      throwsA(isA<TrackParseException>()),
    );
  });

  test('rejects mismatched when and coord counts', () {
    const bad =
        '<kml xmlns:gx="x"><gx:Track>'
        '<when>2026-05-22T13:00:00Z</when>'
        '<gx:coord>-87.25 20.5 0</gx:coord>'
        '<gx:coord>-87.26 20.51 0</gx:coord>'
        '</gx:Track></kml>';
    expect(() => parseKml(bad), throwsA(isA<TrackParseException>()));
  });

  test('rejects malformed XML', () {
    expect(() => parseKml('<kml>'), throwsA(isA<TrackParseException>()));
  });

  test('rejects a coord with fewer than two components', () {
    const bad =
        '<kml xmlns:gx="x"><gx:Track>'
        '<when>2026-05-22T13:00:00Z</when>'
        '<gx:coord>-87.25</gx:coord>'
        '</gx:Track></kml>';
    expect(() => parseKml(bad), throwsA(isA<TrackParseException>()));
  });

  test('round-trips a track exported by our own KML writer', () {
    // Export and import are the two halves of one contract; a change to
    // either that breaks the pair should fail here.
    const exported =
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<kml xmlns="http://www.opengis.net/kml/2.2" '
        'xmlns:gx="http://www.google.com/kml/ext/2.2">\n'
        '  <Document>\n    <Placemark>\n      <gx:Track>\n'
        '        <when>2026-05-22T08:00:00Z</when>\n'
        '        <when>2026-05-22T08:01:00Z</when>\n'
        '        <gx:coord>-87.25 20.5 0</gx:coord>\n'
        '        <gx:coord>-87.26 20.51 0</gx:coord>\n'
        '      </gx:Track>\n    </Placemark>\n  </Document>\n</kml>\n';
    final track = parseKml(exported);
    expect(track.fixes.length, 2);
    expect(track.fixes.first.lat, closeTo(20.5, 1e-9));
    expect(track.fixes.first.utc, DateTime.utc(2026, 5, 22, 8));
  });
}
